-- Isometric renderer. Draws the heightfield as sloped, dither-shaded quads (painter's order,
-- back to front along diagonals) with the truck slotted in at the right depth.

local gfx = playdate.graphics
local floor, ceil, sqrt, cos, sin = math.floor, math.ceil, math.sqrt, math.cos, math.sin

-- 17 opaque 8x8 dither patterns, 0 = white .. 16 = black (Bayer ordered dither).
local patterns = {}
do
    local function bayer(n)
        if n == 1 then return { { 0 } } end
        local p = bayer(n // 2)
        local m = {}
        for y = 1, n do
            m[y] = {}
            for x = 1, n do
                local base = p[(y - 1) % (n // 2) + 1][(x - 1) % (n // 2) + 1] * 4
                local qx, qy = (x - 1) // (n // 2), (y - 1) // (n // 2)
                m[y][x] = base + ({ { 0, 2 }, { 3, 1 } })[qy + 1][qx + 1]
            end
        end
        return m
    end
    local b = bayer(8)
    for level = 0, 16 do
        local rows = {}
        for y = 1, 8 do
            local byte = 0
            for x = 1, 8 do
                if b[y][x] >= level * 4 then byte = byte | (1 << (8 - x)) end -- 1 bit = white
            end
            rows[y] = byte
        end
        patterns[level] = rows
    end
end

local function shadeToLevel(d)
    if d < 0 then d = 0 elseif d > 1 then d = 1 end
    return floor(d * 16 + 0.5)
end

IsoRenderer = {}
IsoRenderer.__index = IsoRenderer

function IsoRenderer.new(map)
    local R = CFG.render
    local r = setmetatable({ map = map, hw = R.tw / 2, hh = R.th / 2, zs = R.zs }, IsoRenderer)

    -- how far beyond the screen we need to look, in diagonal rows, given the map's height range
    local lo, hi = map:heightRange()
    local margin = ceil((hi - lo) * r.zs / r.hh) + 2
    r.rows = ceil(120 / r.hh) + margin
    r.cols = ceil(200 / r.hw) + 2

    -- static terrain shading: surface colour + slope lighting
    r.level = {}
    local len = sqrt(R.lightX ^ 2 + R.lightY ^ 2 + R.lightZ ^ 2)
    local lx, ly, lz = R.lightX / len, R.lightY / len, R.lightZ / len
    for j = 0, map.h - 1 do
        for i = 0, map.w - 1 do
            local gx, gy = map:gradientAt(i + 0.5, j + 0.5)
            local nl = sqrt(gx * gx + gy * gy + 1)
            local lit = (-gx * lx - gy * ly + lz) / nl
            local surf = SURFACES[map.surfaces[j * map.w + i + 1]]
            r.level[j * map.w + i + 1] = shadeToLevel(surf.shade + (lz - lit) * R.lightStrength)
        end
    end
    return r
end

function IsoRenderer:project(x, y, z)
    return (x - y) * self.hw, (x + y) * self.hh - z * self.zs
end

---------------------------------------------------------------- terrain

function IsoRenderer:drawTile(i, j, left, right, top, bottom)
    local map = self.map
    local H, vw = map.heights, map.vw
    local k = j * vw + i + 1
    local hw, hh, zs = self.hw, self.hh, self.zs

    local x0, y0 = (i - j) * hw, (i + j) * hh - H[k] * zs
    local x1, y1 = (i + 1 - j) * hw, (i + j + 1) * hh - H[k + 1] * zs
    local x2, y2 = (i - j) * hw, (i + j + 2) * hh - H[k + vw + 1] * zs
    local x3, y3 = (i - j - 1) * hw, (i + j + 1) * hh - H[k + vw] * zs

    -- cull anything fully outside the view
    if x1 < left or x3 > right then return end
    local ymin, ymax = y0, y0
    if y1 < ymin then ymin = y1 elseif y1 > ymax then ymax = y1 end
    if y2 < ymin then ymin = y2 elseif y2 > ymax then ymax = y2 end
    if y3 < ymin then ymin = y3 elseif y3 > ymax then ymax = y3 end
    if ymax < top or ymin > bottom then return end

    gfx.setPattern(patterns[self.level[j * map.w + i + 1]])
    gfx.fillPolygon(x0, y0, x1, y1, x2, y2, x3, y3)
    if self.gridLines then
        gfx.setColor(gfx.kColorBlack)
        gfx.drawPolygon(x0, y0, x1, y1, x2, y2, x3, y3, x0, y0)
    end
end

---------------------------------------------------------------- truck

function IsoRenderer:drawTruck(truck)
    local P, map = CFG.truck, self.map
    local c, s = cos(truck.heading), sin(truck.heading)
    local half_l, half_w = P.length / 2, P.width / 2
    local lift, bodyH = 0.12, P.bodyHeight

    -- corners: front-left, front-right, back-right, back-left
    local local_pts = { { half_l, -half_w }, { half_l, half_w }, { -half_l, half_w }, { -half_l, -half_w } }
    local gnd, bot, top = {}, {}, {}
    for n = 1, 4 do
        local a, b = local_pts[n][1], local_pts[n][2]
        local wx, wy = truck.x + a * c - b * s, truck.y + a * s + b * c
        local gz = map:heightAt(wx, wy)
        local bz = truck.airborne and truck.z or gz   -- grounded trucks follow the terrain, airborne ones fly flat
        local sx, sy = self:project(wx, wy, gz)
        gnd[n] = { sx, sy }
        sx, sy = self:project(wx, wy, bz + lift)
        bot[n] = { sx, sy }
        sx, sy = self:project(wx, wy, bz + lift + bodyH)
        top[n] = { sx, sy }
    end

    -- shadow on the ground
    gfx.setPattern(patterns[10])
    gfx.fillPolygon(gnd[1][1], gnd[1][2], gnd[2][1], gnd[2][2], gnd[3][1], gnd[3][2], gnd[4][1], gnd[4][2])

    -- wheels
    gfx.setColor(gfx.kColorBlack)
    for n = 1, 4 do gfx.fillCircleAtPoint(bot[n][1], bot[n][2], 3) end

    -- side faces, far to near
    local faces = {}
    for n = 1, 4 do
        local m = n % 4 + 1
        faces[n] = { n, m, (bot[n][2] + bot[m][2]) / 2 }
    end
    table.sort(faces, function(a, b) return a[3] < b[3] end)
    for _, f in ipairs(faces) do
        local a, b = f[1], f[2]
        gfx.setColor(gfx.kColorWhite)
        gfx.fillPolygon(bot[a][1], bot[a][2], bot[b][1], bot[b][2], top[b][1], top[b][2], top[a][1], top[a][2])
        gfx.setColor(gfx.kColorBlack)
        gfx.drawPolygon(bot[a][1], bot[a][2], bot[b][1], bot[b][2], top[b][1], top[b][2], top[a][1], top[a][2],
            bot[a][1], bot[a][2])
    end

    -- roof, with a dark hood so you can tell which way it faces
    gfx.setColor(gfx.kColorWhite)
    gfx.fillPolygon(top[1][1], top[1][2], top[2][1], top[2][2], top[3][1], top[3][2], top[4][1], top[4][2])
    local t = 0.38
    local hx1, hy1 = top[2][1] + (top[3][1] - top[2][1]) * t, top[2][2] + (top[3][2] - top[2][2]) * t
    local hx2, hy2 = top[1][1] + (top[4][1] - top[1][1]) * t, top[1][2] + (top[4][2] - top[1][2]) * t
    gfx.setPattern(patterns[13])
    gfx.fillPolygon(top[1][1], top[1][2], top[2][1], top[2][2], hx1, hy1, hx2, hy2)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawPolygon(top[1][1], top[1][2], top[2][1], top[2][2], top[3][1], top[3][2], top[4][1], top[4][2],
        top[1][1], top[1][2])
    gfx.drawLine(hx1, hy1, hx2, hy2)
end

---------------------------------------------------------------- frame

-- camSX/camSY: the iso-space point to centre on. Draws terrain + truck with the right overlap.
function IsoRenderer:draw(truck, camSX, camSY)
    local map = self.map
    self.gridLines = CFG.render.gridLines
    local ox, oy = floor(200 - camSX + 0.5), floor(120 - camSY + 0.5)
    gfx.setDrawOffset(ox, oy)

    local left, right, top, bottom = -ox - 2, -ox + 402, -oy - 2, -oy + 242
    local s0, u0 = floor(camSY / self.hh), floor(camSX / self.hw)
    local truckRow = floor(truck.x + truck.y) + CFG.render.truckDepthBias
    local truckDone = false
    local w, h = map.w, map.h

    for s = s0 - self.rows, s0 + self.rows do
        if not truckDone and s > truckRow then
            self:drawTruck(truck)
            truckDone = true
        end
        local u = u0 - self.cols
        if (s + u) % 2 ~= 0 then u = u + 1 end
        while u <= u0 + self.cols do
            local i, j = (s + u) // 2, (s - u) // 2
            if i >= 0 and j >= 0 and i < w and j < h then
                self:drawTile(i, j, left, right, top, bottom)
            end
            u = u + 2
        end
    end
    if not truckDone then self:drawTruck(truck) end
    gfx.setColor(gfx.kColorBlack)
end

-- Debug overlay (in iso space, call before resetting the draw offset).
function IsoRenderer:drawDebug(truck)
    local x, y = self:project(truck.x, truck.y, truck.z)
    local vx, vy = self:project(truck.x + truck.vx * 0.3, truck.y + truck.vy * 0.3, truck.z)
    local fx, fy = self:project(truck.x + cos(truck.heading), truck.y + sin(truck.heading), truck.z)
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(3)
    gfx.drawLine(x, y, vx, vy)          -- thick: velocity
    gfx.setLineWidth(1)
    gfx.drawLine(x, y, fx, fy)          -- thin: heading
end

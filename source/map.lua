-- Terrain map: a heightfield plus a surface type per tile.
--
--   * Heights live on tile CORNERS (vertices): (w+1) x (h+1) values, so every tile is a
--     sloped quad. Ramps, hills and pits are just different corner heights.
--   * Surface types live on tiles: w x h values (see surfaces.lua).
--   * Coordinates are 0-based. Tile (i, j) covers world x in [i, i+1], y in [j, j+1].
--
-- No Playdate API in here so it can be unit tested with plain Lua.

local floor, sqrt, cos, pi = math.floor, math.sqrt, math.cos, math.pi

TerrainMap = {}
TerrainMap.__index = TerrainMap

function TerrainMap.new(w, h, surface)
    local m = setmetatable({ w = w, h = h, vw = w + 1, heights = {}, surfaces = {} }, TerrainMap)
    for i = 1, (w + 1) * (h + 1) do m.heights[i] = 0 end
    for i = 1, w * h do m.surfaces[i] = surface or SURFACE.DIRT end
    m.spawn = { x = w / 2, y = h / 2, heading = 0 }
    return m
end

-- Build from flat arrays (row-major, 1-based): heights has (w+1)*(h+1) entries,
-- surfaces has w*h entries. This is the entry point for a Tiled export converter.
function TerrainMap.fromData(data)
    local m = TerrainMap.new(data.w, data.h)
    for i = 1, #m.heights do m.heights[i] = data.heights[i] or 0 end
    for i = 1, #m.surfaces do m.surfaces[i] = data.surfaces[i] or SURFACE.DIRT end
    if data.spawn then m.spawn = data.spawn end
    return m
end

---------------------------------------------------------------- queries

function TerrainMap:heightRange()
    local lo, hi = math.huge, -math.huge
    for _, v in ipairs(self.heights) do
        if v < lo then lo = v end
        if v > hi then hi = v end
    end
    return lo, hi
end

-- Returns the tile column/row and the position within the tile (clamped to the map).
function TerrainMap:locate(x, y)
    local w, h = self.w, self.h
    if x < 0 then x = 0 elseif x > w then x = w end
    if y < 0 then y = 0 elseif y > h then y = h end
    local i, j = floor(x), floor(y)
    if i >= w then i = w - 1 end
    if j >= h then j = h - 1 end
    return i, j, x - i, y - j
end

function TerrainMap:heightAt(x, y)
    local i, j, u, v = self:locate(x, y)
    local H, k = self.heights, j * self.vw + i + 1
    local h00, h10, h01, h11 = H[k], H[k + 1], H[k + self.vw], H[k + self.vw + 1]
    return h00 * (1 - u) * (1 - v) + h10 * u * (1 - v) + h01 * (1 - u) * v + h11 * u * v
end

-- Slope of the ground: dh/dx, dh/dy.
function TerrainMap:gradientAt(x, y)
    local i, j, u, v = self:locate(x, y)
    local H, k = self.heights, j * self.vw + i + 1
    local h00, h10, h01, h11 = H[k], H[k + 1], H[k + self.vw], H[k + self.vw + 1]
    return (1 - v) * (h10 - h00) + v * (h11 - h01), (1 - u) * (h01 - h00) + u * (h11 - h10)
end

function TerrainMap:surfaceAt(x, y)
    local i, j = self:locate(x, y)
    return SURFACES[self.surfaces[j * self.w + i + 1]]
end

---------------------------------------------------------------- editing helpers

local function clampi(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end

function TerrainMap:setVertex(vx, vy, z)
    if vx < 0 or vy < 0 or vx > self.w or vy > self.h then return end
    self.heights[vy * self.vw + vx + 1] = z
end

function TerrainMap:getVertex(vx, vy)
    return self.heights[clampi(vy, 0, self.h) * self.vw + clampi(vx, 0, self.w) + 1]
end

-- Set every corner in the inclusive vertex rectangle to z.
function TerrainMap:setHeightRect(x0, y0, x1, y1, z)
    for vy = y0, y1 do for vx = x0, x1 do self:setVertex(vx, vy, z) end end
end

-- Linear ramp across the inclusive vertex rectangle, rising along 'x' or 'y'.
function TerrainMap:ramp(x0, y0, x1, y1, zFrom, zTo, axis)
    for vy = y0, y1 do
        for vx = x0, x1 do
            local t
            if axis == "y" then t = (vy - y0) / (y1 - y0) else t = (vx - x0) / (x1 - x0) end
            self:setVertex(vx, vy, zFrom + (zTo - zFrom) * t)
        end
    end
end

-- Add a smooth round bump (negative height = crater) centred at (cx, cy) world units.
function TerrainMap:bump(cx, cy, radius, height)
    for vy = floor(cy - radius), floor(cy + radius) + 1 do
        for vx = floor(cx - radius), floor(cx + radius) + 1 do
            local d = sqrt((vx - cx) ^ 2 + (vy - cy) ^ 2)
            if d < radius then
                self:setVertex(vx, vy, self:getVertex(vx, vy) + height * 0.5 * (1 + cos(pi * d / radius)))
            end
        end
    end
end

-- Set the surface of every tile in the inclusive tile rectangle.
function TerrainMap:fillSurface(x0, y0, x1, y1, surface)
    for j = y0, y1 do
        for i = x0, x1 do
            if i >= 0 and j >= 0 and i < self.w and j < self.h then
                self.surfaces[j * self.w + i + 1] = surface
            end
        end
    end
end

-- Surface for every tile whose centre lies within radius of (cx, cy).
function TerrainMap:fillSurfaceCircle(cx, cy, radius, surface)
    for j = floor(cy - radius), floor(cy + radius) do
        for i = floor(cx - radius), floor(cx + radius) do
            if (i + 0.5 - cx) ^ 2 + (j + 0.5 - cy) ^ 2 <= radius ^ 2 then
                self:fillSurface(i, j, i, j, surface)
            end
        end
    end
end

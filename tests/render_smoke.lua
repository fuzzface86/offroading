-- Runs the renderer against a stubbed Playdate graphics API to catch runtime errors and
-- report draw-call counts. Run from the repo root: lua tests/render_smoke.lua
local calls = setmetatable({}, { __index = function() return 0 end })
local gfx = setmetatable({ kColorBlack = 0, kColorWhite = 1 }, {
    __index = function(_, name)
        return function(...)
            calls[name] = calls[name] + 1
            if name == "setPattern" then
                local t = ...
                assert(#t == 8, "pattern must have 8 rows")
                for _, b in ipairs(t) do assert(math.type(b) == "integer" and b >= 0 and b <= 255) end
            end
            for i = 1, select("#", ...) do
                local v = select(i, ...)
                if type(v) == "number" then assert(v == v and v ~= math.huge and v ~= -math.huge, name .. " got NaN/inf") end
            end
        end
    end,
})
playdate = { graphics = gfx }

for _, f in ipairs { "config", "surfaces", "map", "truck", "levels/test_level", "render" } do
    dofile("source/" .. f .. ".lua")
end

local world = buildTestLevel()
local truck = Truck.new(world, world.spawn.x, world.spawn.y, world.spawn.heading)
local r = IsoRenderer.new(world)
print("render rows/cols:", r.rows, r.cols)

local camx, camy = r:project(truck.x, truck.y, truck.z)
for frame = 1, 600 do
    truck:update(CFG.dt, { gas = 1, steer = (frame % 120 < 30) and 1 or 0 }, world)
    camx, camy = r:project(truck.x, truck.y, truck.z)
    r:draw(truck, camx, camy)
    r:drawDebug(truck)
end
print("fillPolygon per frame:", calls.fillPolygon / 600, " drawPolygon per frame:", calls.drawPolygon / 600)

-- sweep camera over the whole map to catch out-of-range indexing
for x = 1, world.w - 1, 3 do
    for y = 1, world.h - 1, 3 do
        local t = Truck.new(world, x, y, 0)
        r:draw(t, r:project(x, y, t.z))
    end
end
print("OK")

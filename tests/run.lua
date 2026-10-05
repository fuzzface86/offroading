-- Plain-Lua tests for the pure modules. Run from the repo root: lua tests/run.lua
for _, f in ipairs { "config", "surfaces", "map", "truck", "levels/test_level" } do
    dofile("source/" .. f .. ".lua")
end

local failures, total = 0, 0
local function check(name, ok, detail)
    total = total + 1
    if not ok then failures = failures + 1 end
    print(string.format("%s  %s%s", ok and "PASS" or "FAIL", name, detail and ("  (" .. detail .. ")") or ""))
end

local function flat(surface, w, h)
    return TerrainMap.new(w or 60, h or 60, surface or SURFACE.DIRT)
end

local function drive(truck, world, seconds, input)
    for _ = 1, math.floor(seconds / CFG.dt) do truck:update(CFG.dt, input, world) end
end

local GAS = { gas = 1 }

-- terrain queries ---------------------------------------------------------
do
    local m = flat()
    m:ramp(10, 0, 20, 60, 0, 5, "x")          -- slope 0.5
    check("height interpolates", math.abs(m:heightAt(15, 30) - 2.5) < 1e-9)
    local gx, gy = m:gradientAt(15.3, 30.2)
    check("gradient of a ramp", math.abs(gx - 0.5) < 1e-9 and math.abs(gy) < 1e-9)
    check("surface lookup", m:surfaceAt(3, 3) == SURFACES[SURFACE.DIRT])
end

-- driving on flat ground --------------------------------------------------
do
    local m = flat()
    local t = Truck.new(m, 5, 30, 0)
    drive(t, m, 6, GAS)
    check("accelerates to near top speed", t.speed > CFG.truck.topSpeed * 0.7 and t.speed <= CFG.truck.topSpeed,
        string.format("speed %.2f", t.speed))
    local frames = 0
    while t.vx > 0.3 and frames < 300 do t:update(CFG.dt, { brake = 1 }, m); frames = frames + 1 end
    check("brakes from top speed in under 1.5s", frames < 45, string.format("%d frames", frames))
    local t2 = Truck.new(m, 30, 30, 0)
    drive(t2, m, 2, { brake = 1 })
    check("brake from rest reverses", t2.vx < -1, string.format("vx %.2f", t2.vx))
    local t3 = Truck.new(m, 5, 30, 0)
    drive(t3, m, 3, GAS); local spd = t3.speed
    drive(t3, m, 10, {})
    check("coasts to a stop", t3.speed < 0.01 and spd > 3)
end

-- surfaces ----------------------------------------------------------------
do
    local function topAfter(surface)
        local m = flat(surface); local t = Truck.new(m, 5, 30, 0)
        drive(t, m, 2.5, GAS); return t.speed
    end
    local road, dirt, mud = topAfter(SURFACE.ROAD), topAfter(SURFACE.DIRT), topAfter(SURFACE.MUD)
    check("road faster than dirt faster than mud", road > dirt and dirt > mud,
        string.format("road %.1f dirt %.1f mud %.1f", road, dirt, mud))
end

-- steering ----------------------------------------------------------------
do
    local m = flat()
    local t = Truck.new(m, 30, 30, 0)
    drive(t, m, 2, GAS)
    local h0 = t.heading
    drive(t, m, 1, { gas = 1, steer = 1 })
    check("steer right increases heading", t.heading - h0 > 0.5, string.format("dh %.2f", t.heading - h0))
    local t2 = Truck.new(m, 30, 30, 0)
    drive(t2, m, 0.5, { steer = 1 })
    check("no turning while stationary", math.abs(t2.heading) < 1e-6)
    -- drift on mud: velocity direction lags the heading
    local mm = flat(SURFACE.DIRT, 120, 120); local t3 = Truck.new(mm, 10, 60, 0)
    drive(t3, mm, 4, GAS); drive(t3, mm, 0.4, { gas = 1, steer = 1 })
    local vAngle = math.atan(t3.vy, t3.vx)
    check("slides when cornering hard at speed", t3.heading - vAngle > 0.05,
        string.format("lag %.2f rad", t3.heading - vAngle))
end

-- slopes ------------------------------------------------------------------
do
    local function climb(slope, surface)
        local m = flat(surface); m:ramp(0, 0, 60, 60, 0, 60 * slope, "x")
        local t = Truck.new(m, 5, 30, 0)
        drive(t, m, 8, GAS)
        return t.x
    end
    check("climbs a gentle slope on dirt", climb(0.2, SURFACE.DIRT) > 30, string.format("x %.1f", climb(0.2, SURFACE.DIRT)))
    check("stalls on a steep slope in mud", climb(0.7, SURFACE.MUD) < 12, string.format("x %.1f", climb(0.7, SURFACE.MUD)))
    check("steeper slope is slower on dirt", climb(0.6, SURFACE.DIRT) < climb(0.3, SURFACE.DIRT))
    check("mud climbs worse than dirt", climb(0.45, SURFACE.MUD) < climb(0.45, SURFACE.DIRT))

    local m = flat(); m:ramp(0, 0, 60, 60, 0, 12, "x")   -- slope 0.2
    local t = Truck.new(m, 30, 30, 0)
    drive(t, m, 5, {})
    check("parks on a moderate slope", math.abs(t.x - 30) < 0.05, string.format("moved %.3f", t.x - 30))
    local steep = flat(); steep:ramp(0, 0, 60, 60, 0, 48, "x")   -- slope 0.8
    local t2 = Truck.new(steep, 30, 30, 0)
    drive(t2, steep, 3, {})
    check("rolls down a steep slope", t2.x < 29, string.format("moved %.2f", t2.x - 30))
    -- sideways on a slope
    local t3 = Truck.new(m, 30, 30, math.pi / 2)
    drive(t3, m, 5, {})
    check("parked sideways on a slope doesn't creep", math.abs(t3.x - 30) < 0.05)
end

-- jumps and walls ---------------------------------------------------------
do
    local m = flat()
    m:ramp(20, 0, 24, 60, 0, 1.6, "x")
    local t = Truck.new(m, 10, 30, 0)
    local wasAir, maxAirZ = false, 0
    for _ = 1, 30 * 8 do
        t:update(CFG.dt, GAS, m)
        if t.airborne then wasAir = true; maxAirZ = math.max(maxAirZ, t.z) end
    end
    check("launches off a ramp and lands", wasAir and not t.airborne and t.impact >= 0 and maxAirZ > 1.6,
        string.format("max z %.2f", maxAirZ))
    check("lands back at ground level", math.abs(t.z - m:heightAt(t.x, t.y)) < 1e-6)

    local wall = flat(); wall:setHeightRect(30, 0, 60, 60, 4)  -- 4-high cliff in one tile
    local tw = Truck.new(wall, 20, 30, 0)
    drive(tw, wall, 6, GAS)
    check("cliff acts as a wall", tw.x < 30.01, string.format("x %.2f", tw.x))

    local te = Truck.new(m, 5, 30, math.pi)
    drive(te, m, 5, GAS)
    check("stays inside world bounds", te.x >= 0 and te.x <= m.w and te.y >= 0 and te.y <= m.h)
end

-- the shipped level -------------------------------------------------------
do
    local lvl = buildTestLevel()
    local t = Truck.new(lvl, lvl.spawn.x, lvl.spawn.y, lvl.spawn.heading)
    drive(t, lvl, 12, { gas = 1 })
    check("test level: truck drives east without errors", t.x > 20 and t.x < lvl.w,
        string.format("x %.1f z %.2f", t.x, t.z))
    local lo, hi = lvl:heightRange()
    check("test level height range sane", lo < 0 and hi > 4, string.format("%.1f..%.1f", lo, hi))
end

print(string.format("\n%d/%d passed", total - failures, total))
os.exit(failures == 0 and 0 or 1)

-- Hand-built test level exercising every obstacle type. Replace with Tiled exports later.

function buildTestLevel()
    local m = TerrainMap.new(64, 64, SURFACE.GRASS)

    -- Main dirt track running west -> east.
    m:fillSurface(2, 28, 61, 35, SURFACE.DIRT)

    -- Long gentle incline up onto a plateau (slope 0.17), then a steeper drop (0.29).
    m:ramp(10, 28, 22, 36, 0, 2.0, "x")
    m:setHeightRect(23, 28, 32, 36, 2.0)
    m:ramp(32, 28, 39, 36, 2.0, 0, "x")
    m:fillSurface(10, 28, 38, 35, SURFACE.ROCK)

    -- Jump: kicker ramp (slope 0.4) then a sheer drop, landing on flat dirt.
    m:ramp(43, 28, 47, 36, 0, 1.6, "x")

    -- Mud bog after the landing zone.
    m:fillSurface(50, 28, 57, 35, SURFACE.MUD)
    m:bump(54, 32, 3, -0.3)

    -- Sand dunes.
    m:fillSurface(4, 4, 22, 20, SURFACE.SAND)
    m:bump(10, 10, 5, 1.6)
    m:bump(17, 14, 4, 1.2)
    m:bump(8, 17, 3.5, 0.9)

    -- Rock garden: lots of small bumps (deterministic pseudo-random).
    m:fillSurface(30, 5, 52, 22, SURFACE.ROCK)
    local seed = 12345
    local function rnd()
        seed = (seed * 1103515245 + 12345) % 2147483648
        return seed / 2147483648
    end
    for _ = 1, 22 do
        m:bump(31 + rnd() * 20, 6 + rnd() * 15, 1.2 + rnd() * 1.0, 0.3 + rnd() * 0.6)
    end

    -- Crater (pit) with a muddy floor. Max wall slope = depth * pi / (2 * radius) ~ 0.6.
    m:bump(14, 48, 6, -2.4)
    m:fillSurfaceCircle(14, 48, 2.5, SURFACE.MUD)

    -- Big grassy hill with steep sides (max slope ~ 0.78): try to reach the top.
    m:bump(46, 48, 8, 5)

    -- Paved strip to warm up on.
    m:fillSurface(2, 36, 28, 38, SURFACE.ROAD)

    m.spawn = { x = 5, y = 32, heading = 0 }
    return m
end

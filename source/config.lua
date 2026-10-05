-- All the knobs for tweaking the driving feel live here.
-- Units: 1 tile = 1 world unit. Speeds are tiles/second, accelerations tiles/second^2.
-- Height (z) uses the same unit as a tile, so a slope of 0.5 rises half a tile per tile travelled.

CFG = {
    dt = 1 / 30,          -- fixed physics step (matches Playdate's default 30 fps)
    substeps = 2,         -- physics sub-steps per frame (more = steadier at high speed)
    gravity = 11,         -- pulls the truck down slopes and back down after jumps

    truck = {
        -- body
        length = 1.5,
        width = 0.85,
        wheelbase = 1.0,
        bodyHeight = 0.45,

        -- engine / brakes
        engineAccel = 10,       -- full-throttle acceleration on grippy ground
        topSpeed = 9,           -- engine stops pushing at this speed
        reverseAccel = 5,
        reverseTop = 3,
        reverseThreshold = 0.3, -- below this forward speed, the brake button reverses
        brakeDecel = 14,
        rollingDecel = 1.2,     -- constant resistance (scaled by surface drag)
        airDrag = 0.02,         -- speed-squared resistance
        holdSpeed = 1.0,        -- below this speed with no throttle, the truck "parks"...
        holdDecel = 5,          -- ...holding on slopes up to roughly holdDecel / gravity

        -- steering
        maxSteer = 0.65,        -- radians of wheel angle at full lock
        steerRate = 3.5,        -- how fast the wheel moves toward the stick (full lock per 1/rate s)
        steerSpeedFalloff = 0.12, -- reduces lock at speed (higher = less twitchy)

        -- grip
        lateralGrip = 16,       -- max sideways correction accel (scaled by surface grip)
        throttleGripPenalty = 0.35, -- throttle loosens the rear (drifty at 1.0)

        -- terrain interaction
        maxClimbSlope = 1.0,    -- slopes steeper than this act as walls
        stepHeight = 0.35,      -- airborne trucks bonk into terrain taller than this
        stickDistance = 0.06,   -- ground contact tolerance before the truck leaves the ground
        wallBounce = 0.25,      -- how much speed bounces back off walls / world edge
    },

    input = {
        crankGain = 1 / 25,     -- steering added per degree of crank rotation each frame
    },

    camera = {
        follow = 0.18,          -- 0..1, higher = tighter
        lookahead = 0.35,       -- seconds of velocity to look ahead
    },

    render = {
        tw = 32,                -- tile diamond width in pixels
        th = 16,                -- tile diamond height in pixels
        zs = 14,                -- pixels per unit of height
        gridLines = true,       -- outline every tile (helps read terrain in 1-bit)
        truckDepthBias = 2,     -- draw the truck after this many diagonals past its own
        lightX = -0.6, lightY = -0.2, lightZ = 0.75, -- light direction for slope shading
        lightStrength = 0.9,
    },
}

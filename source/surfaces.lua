-- Terrain surface types. grip/traction/drag/steer are multipliers on the truck tuning in config.lua.
--   grip     sideways + braking friction
--   traction how much engine power reaches the ground
--   drag     rolling resistance
--   steer    steering responsiveness
--   shade    base darkness for rendering (0 = white, 1 = black)

SURFACE = { ROAD = 1, DIRT = 2, GRASS = 3, MUD = 4, SAND = 5, ROCK = 6 }

SURFACES = {
    [SURFACE.ROAD]  = { name = "ROAD",  grip = 1.3,  traction = 1.15, drag = 0.8, steer = 1.0,  shade = 0.18 },
    [SURFACE.DIRT]  = { name = "DIRT",  grip = 1.0,  traction = 1.0,  drag = 1.0, steer = 1.0,  shade = 0.30 },
    [SURFACE.GRASS] = { name = "GRASS", grip = 0.8,  traction = 0.85, drag = 1.3, steer = 0.95, shade = 0.12 },
    [SURFACE.MUD]   = { name = "MUD",   grip = 0.35, traction = 0.55, drag = 2.6, steer = 0.8,  shade = 0.62 },
    [SURFACE.SAND]  = { name = "SAND",  grip = 0.6,  traction = 0.7,  drag = 2.0, steer = 0.9,  shade = 0.06 },
    [SURFACE.ROCK]  = { name = "ROCK",  grip = 1.2,  traction = 1.0,  drag = 1.1, steer = 1.0,  shade = 0.45 },
}

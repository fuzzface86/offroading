# Offroading (Playdate)

Isometric offroad truck driving for the Playdate, written in Lua.

## Run it

1. Install the [Playdate SDK](https://play.date/dev/) and set `PLAYDATE_SDK_PATH`.
2. `make run` (or `pdc source offroading.pdx` and open the `.pdx` in the Simulator).

`make test` runs the physics and renderer smoke tests with plain Lua 5.4 (no SDK needed).

## Controls

| Input | Action |
| --- | --- |
| A or Up | Gas |
| B or Down | Brake, then reverse |
| Left / Right | Steer |
| Crank | Steer (turn on "Crank steer" in the system menu) |

System menu: **Reset truck**, **Crank steer**, **Debug** (velocity and heading arrows).

## Layout

```
source/
  main.lua          input, camera, HUD, game loop
  config.lua        every tuning value (start here to change the feel)
  surfaces.lua      terrain types: grip, traction, drag, steering, shade
  map.lua           heightfield + surface grid, query and editing helpers
  truck.lua         driving physics (pure Lua, no Playdate calls)
  render.lua        isometric renderer
  levels/test_level.lua   hand-built level with every obstacle type
tests/              plain-Lua tests
```

## How the terrain works

- **Heights are on tile corners**, so every tile is a sloped quad. A ramp is a row of rising corner
  heights, a pit is a ring of falling ones, a cliff is a big jump between neighbours.
- **Surfaces are per tile** (`ROAD DIRT GRASS MUD SAND ROCK`) and scale the truck's grip, traction,
  rolling drag and steering. Add a new one in `surfaces.lua`.
- The truck feels the ground slope as gravity, walls steeper than `maxClimbSlope` stop it, and
  crests that fall away faster than gravity launch it into the air.

Units: 1 tile = 1 world unit, heights use the same unit.

## Tweaking the feel

All in `config.lua`:

- Too sluggish / too fast: `engineAccel`, `topSpeed`
- Slopes feel too punishing: lower `gravity`
- Want more drift: lower `lateralGrip`, raise `throttleGripPenalty`
- Twitchy steering: lower `maxSteer`, raise `steerSpeedFalloff`
- Jumps too floaty / too short: `gravity` also controls air time
- Slow frame rate: set `render.gridLines = false`, or make the view smaller (`tw`/`th`)

## Next: Tiled

`TerrainMap.fromData{ w, h, heights, surfaces, spawn }` takes flat arrays
(`heights` has `(w+1)*(h+1)` entries, `surfaces` has `w*h`), so a Tiled export converter only needs to
produce that table. The plan is a height layer + surface layer in Tiled, exported to Lua.

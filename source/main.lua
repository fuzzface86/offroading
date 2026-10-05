import "CoreLibs/graphics"

import "config"
import "surfaces"
import "map"
import "truck"
import "levels/test_level"
import "render"

local gfx = playdate.graphics
local floor = math.floor

local world = buildTestLevel()
local truck = Truck.new(world, world.spawn.x, world.spawn.y, world.spawn.heading)
local renderer = IsoRenderer.new(world)
local cam = { x = 0, y = 0 }
local crankSteering = false
local debug = false

local function resetTruck()
    truck:reset(world, world.spawn.x, world.spawn.y, world.spawn.heading)
    cam.x, cam.y = renderer:project(truck.x, truck.y, truck.z)
end
resetTruck()

local menu = playdate.getSystemMenu()
menu:addMenuItem("Reset truck", resetTruck)
menu:addCheckmarkMenuItem("Crank steer", false, function(v) crankSteering = v end)
menu:addCheckmarkMenuItem("Debug", false, function(v) debug = v end)

-- A / Up = gas, B / Down = brake (then reverse), Left / Right = steer, crank = optional steer.
local function readInput()
    local steer = 0
    if playdate.buttonIsPressed(playdate.kButtonLeft) then steer = steer - 1 end
    if playdate.buttonIsPressed(playdate.kButtonRight) then steer = steer + 1 end
    if crankSteering and not playdate.isCrankDocked() then
        steer = steer + playdate.getCrankChange() * CFG.input.crankGain
        if steer > 1 then steer = 1 elseif steer < -1 then steer = -1 end
    end
    local gas = (playdate.buttonIsPressed(playdate.kButtonA) or playdate.buttonIsPressed(playdate.kButtonUp)) and 1 or 0
    local brake = (playdate.buttonIsPressed(playdate.kButtonB) or playdate.buttonIsPressed(playdate.kButtonDown)) and 1 or 0
    return { gas = gas, brake = brake, steer = steer }
end

local function drawHud()
    gfx.setDrawOffset(0, 0)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(0, 0, 118, 38)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(0, 0, 118, 38)
    gfx.drawText(string.format("SPD %4.1f  %s", truck.speed, truck.airborne and "AIR" or truck.surface.name), 4, 3)
    gfx.drawText(string.format("SLOPE %3d%%", floor(truck.slope * 100 + 0.5)), 4, 20)
end

function playdate.update()
    truck:update(CFG.dt, readInput(), world)

    -- camera eases toward the truck, looking a little ahead of where it's going
    local C = CFG.camera
    local tx, ty = renderer:project(truck.x + truck.vx * C.lookahead, truck.y + truck.vy * C.lookahead, truck.z)
    cam.x = cam.x + (tx - cam.x) * C.follow
    cam.y = cam.y + (ty - cam.y) * C.follow

    gfx.clear(gfx.kColorWhite)
    renderer:draw(truck, cam.x, cam.y)
    if debug then renderer:drawDebug(truck) end
    drawHud()
    playdate.drawFPS(372, 224)
end

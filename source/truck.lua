-- Truck driving physics. No Playdate API in here so it can be unit tested with plain Lua.
--
-- World: x/y on the ground plane, z up. The truck has a world-space velocity (vx, vy) which is
-- split each step into a forward part (vf) and a sideways part (vl) relative to its heading.
--   forward = (cos h, sin h), right = (-sin h, cos h). Positive steer turns right.
--
-- Each step on the ground:
--   1. gravity pulls along the slope
--   2. throttle / brake / rolling resistance act on the forward speed
--   3. tyres cancel sideways speed, up to a grip limit (beyond that you slide)
--   4. a bicycle model turns the heading from steering angle and forward speed
-- Drive off a crest fast enough and the truck leaves the ground and flies ballistically.

local abs, sqrt, cos, sin, tan, max = math.abs, math.sqrt, math.cos, math.sin, math.tan, math.max

local function clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
end

Truck = {}
Truck.__index = Truck

function Truck.new(world, x, y, heading)
    local t = setmetatable({}, Truck)
    t:reset(world, x, y, heading)
    return t
end

function Truck:reset(world, x, y, heading)
    self.x, self.y, self.heading = x, y, heading or 0
    self.vx, self.vy = 0, 0
    self.z = world:heightAt(x, y)
    self.vz = 0
    self.steer = 0           -- current wheel position, -1..1
    self.airborne = false
    self.impact = 0          -- vertical speed of the hardest landing this frame
    self.speed = 0
    self.slope = 0
    self.surface = world:surfaceAt(x, y)
end

-- input: { gas = 0..1, brake = 0..1, steer = -1..1 }
function Truck:update(dt, input, world)
    self.impact = 0
    local n = CFG.substeps
    for _ = 1, n do self:step(dt / n, input, world) end
    self.speed = sqrt(self.vx * self.vx + self.vy * self.vy)
end

function Truck:step(dt, input, world)
    local P, G = CFG.truck, CFG.gravity
    local gas, brake = input.gas or 0, input.brake or 0

    -- the wheel eases toward the requested angle
    local maxd = P.steerRate * dt
    self.steer = self.steer + clamp((input.steer or 0) - self.steer, -maxd, maxd)

    local c, s = cos(self.heading), sin(self.heading)
    local vf = self.vx * c + self.vy * s
    local vl = -self.vx * s + self.vy * c
    local surf = world:surfaceAt(self.x, self.y)
    self.surface = surf
    local yaw = 0

    if not self.airborne then
        -- 1. gravity along the slope
        local gx, gy = world:gradientAt(self.x, self.y)
        self.slope = sqrt(gx * gx + gy * gy)
        local pull = G / sqrt(1 + gx * gx + gy * gy)
        vf = vf - pull * (gx * c + gy * s) * dt
        vl = vl - pull * (-gx * s + gy * c) * dt

        -- 2. engine, brakes, resistance
        if gas > 0 then
            local room = max(0, 1 - max(vf, 0) / P.topSpeed)
            vf = vf + P.engineAccel * surf.traction * gas * room * dt
        end
        if brake > 0 then
            if vf > P.reverseThreshold then
                vf = max(0, vf - P.brakeDecel * surf.grip * brake * dt)
            else
                local room = max(0, 1 - max(-vf, 0) / P.reverseTop)
                vf = vf - P.reverseAccel * surf.traction * brake * room * dt
            end
        end
        local d = P.rollingDecel * surf.drag + P.airDrag * vf * vf
        if gas == 0 and brake == 0 and abs(vf) < P.holdSpeed then d = d + P.holdDecel * surf.grip end
        d = d * dt
        if abs(vf) <= d then vf = 0 elseif vf > 0 then vf = vf - d else vf = vf + d end

        -- 3. tyres: cancel sideways speed up to the grip limit
        local maxLat = P.lateralGrip * surf.grip * (1 - P.throttleGripPenalty * gas)
        vl = vl + clamp(-vl, -maxLat * dt, maxLat * dt)

        -- 4. steering (bicycle model)
        local angle = self.steer * P.maxSteer / (1 + P.steerSpeedFalloff * abs(vf))
        yaw = vf / P.wheelbase * tan(angle) * surf.steer
    end

    -- back to world velocity using the heading we measured against, then turn
    self.vx = vf * c - vl * s
    self.vy = vf * s + vl * c
    self.heading = self.heading + yaw * dt

    -- move, bouncing off the world edge and walls too steep to climb
    local nx, ny = self.x + self.vx * dt, self.y + self.vy * dt
    local m = P.width * 0.5
    if nx < m then nx = m; if self.vx < 0 then self.vx = -self.vx * P.wallBounce end end
    if nx > world.w - m then nx = world.w - m; if self.vx > 0 then self.vx = -self.vx * P.wallBounce end end
    if ny < m then ny = m; if self.vy < 0 then self.vy = -self.vy * P.wallBounce end end
    if ny > world.h - m then ny = world.h - m; if self.vy > 0 then self.vy = -self.vy * P.wallBounce end end

    local gx, gy = world:gradientAt(nx, ny)
    local gm = sqrt(gx * gx + gy * gy)
    local blocked
    if self.airborne then
        blocked = world:heightAt(nx, ny) - self.z > P.stepHeight
    else
        blocked = gm > P.maxClimbSlope and (self.vx * gx + self.vy * gy) > 0
    end
    if blocked then
        local ax, ay
        if gm > 1e-3 then
            ax, ay = gx / gm, gy / gm
        else
            local sp = max(sqrt(self.vx * self.vx + self.vy * self.vy), 1e-6)
            ax, ay = self.vx / sp, self.vy / sp
        end
        local vn = self.vx * ax + self.vy * ay
        if vn > 0 then
            self.vx = self.vx - (1 + P.wallBounce) * vn * ax
            self.vy = self.vy - (1 + P.wallBounce) * vn * ay
        end
        nx, ny = self.x, self.y
    end
    self.x, self.y = nx, ny

    -- vertical: stick to the ground, or fly if the ground falls away faster than gravity
    local ground = world:heightAt(self.x, self.y)
    local vzNext = self.vz - G * dt
    local zBallistic = self.z + vzNext * dt
    if self.airborne then
        if zBallistic <= ground then
            self.impact = max(self.impact, -vzNext)
            self.z, self.vz, self.airborne = ground, 0, false
        else
            self.z, self.vz = zBallistic, vzNext
        end
    else
        if ground >= zBallistic - P.stickDistance then
            self.vz = (ground - self.z) / dt
            self.z = ground
        else
            self.airborne = true
            self.z, self.vz = zBallistic, vzNext
        end
    end
end

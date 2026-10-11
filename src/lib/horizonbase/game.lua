-- MoonLoader / GTA SA 1.0 US integration. Native field offsets follow Plugin-SDK.
local logic = require 'horizonbase.logic'
local M = {}; M.__index = M
local boatModels = {[430]=true,[446]=true,[452]=true,[453]=true,[454]=true,[472]=true,[473]=true,[484]=true,[493]=true,[595]=true}

local function call(name, fallback, ...)
    if type(_G[name]) ~= 'function' then return fallback end
    local ok, value, output = pcall(_G[name], ...)
    if not ok then return fallback end
    -- Conditional SCM getters can return (status, output), e.g. storeWantedLevel.
    -- Preserve predicate booleans, but use the typed output for numeric/string getters.
    if type(value)=='boolean' and type(fallback)~='boolean' then value=output end
    if type(value)~=type(fallback) then return fallback end
    if type(value)=='number' and (value~=value or math.abs(value)==math.huge) then return fallback end
    return value
end

function M.new(config, notify)
    return setmetatable({config=config, notify=notify, sample={ready=false},
        cruise={active=false, target=0}, maxStamina=0, maxBreath=0,
        keysOverridden=false,ammoHistory={},reloadGuard=require('horizonbase.reload_guard').new()}, M)
end

function M:readPlayerEnergy(ped)
    local memory = require 'memory'
    local ptr = call('getCharPointer', 0, ped)
    if ptr == 0 then return end
    local playerData = memory.getuint32(ptr + 0x480, false)
    if playerData < 0x10000 then return end
    local stamina, breath = memory.getfloat(playerData + 0x18, false), memory.getfloat(playerData + 0x44, false)
    if stamina == stamina and stamina >= 0 and stamina < 100000 then
        self.maxStamina = math.max(self.maxStamina, stamina)
        self.sample.stamina = self.maxStamina > 0 and logic.clamp(stamina/self.maxStamina, 0, 1) or 1
    end
    if breath == breath and breath >= 0 and breath < 100000 then
        self.maxBreath = math.max(self.maxBreath, breath)
        self.sample.oxygen = self.maxBreath > 0 and logic.clamp(breath/self.maxBreath, 0, 1) or 1
    end
end

function M:readNativeState(ped)
    local memory=require 'memory'
    local ptr=call('getCharPointer',0,ped)
    if ptr<0x10000 then return end
    -- Read the actual float; GET_CHAR_HEALTH can round it and add one.
    local health=memory.getfloat(ptr+0x540,false)
    if health==health and health>=0 and health<100000000 then self.sample.rawHealth=health end
    local slot=memory.getuint8(ptr+0x718,false)
    if slot>12 then return end
    local weapon=ptr+0x5A0+slot*0x1C
    if memory.getuint32(weapon,false)~=self.sample.weapon then return end
    self.sample.ammoClip=memory.getuint32(weapon+0x8,false)
    self.sample.ammoTotal=memory.getuint32(weapon+0xC,false)
    local last=self.lastAmmo
    local current={weapon=self.sample.weapon,clip=self.sample.ammoClip,total=self.sample.ammoTotal}
    if not last or last.weapon~=current.weapon or last.clip~=current.clip or last.total~=current.total then
        self.ammoHistory[#self.ammoHistory+1]=('t=%d weapon=%d magazine=%d engine_total=%d'):format(
            call('getGameTimer',0),current.weapon,current.clip,current.total)
        if #self.ammoHistory>24 then table.remove(self.ammoHistory,1) end
        self.lastAmmo=current
    end
end

function M:refresh()
    local ped = _G.PLAYER_PED
    local ready = ped ~= nil and call('doesCharExist', false, ped) and call('isSampAvailable', false) and
        call('sampGetGamestate',5)==3
    local s = {ready=ready, alive=false, vehicle=false, swimming=false, underwater=false, stamina=1, oxygen=1}
    self.sample = s
    if not ready then self:stopCruise(); return s end
    local skin=call('getCharModel',-1,ped)
    if skin>=0 and skin<=311 and skin==math.floor(skin) then s.skin=skin end
    local id=call('sampGetPlayerIdByCharHandle',-1,ped)
    if id>=0 and id<=1004 and id==math.floor(id) then s.playerId=id end
    s.alive = not call('isCharDead', true, ped)
    s.x, s.y, s.z = getCharCoordinates(ped)
    s.heading = call('getCharHeading', 0, ped)
    s.health = call('getCharHealth', 0, ped)
    s.armour = call('getCharArmour', 0, ped)
    s.money = call('getPlayerMoney', 0, PLAYER_HANDLE)
    if type(_G.getTimeOfDay)=='function' then
        local ok,hour,minute=pcall(getTimeOfDay)
        if ok and type(hour)=='number' and type(minute)=='number' and hour==hour and minute==minute and
            hour>=0 and hour<24 and minute>=0 and minute<60 then
            s.hour=math.floor(hour);s.minute=math.floor(minute)
        end
    end
    s.weapon = call('getCurrentCharWeapon', 0, ped)
    s.ammo = call('getAmmoInCharWeapon', 0, ped, s.weapon)
    s.wanted = logic.clamp(math.floor(call('storeWantedLevel', 0, PLAYER_HANDLE)),0,6)
    s.swimming = call('isCharSwimming', false, ped)
    s.swimState = s.swimming and call('getCharSwimState', 0, ped) or 0
    s.underwater = s.swimming and s.swimState>=3
    s.running = call('getCharSpeed',0,ped)>2.5 or call('getPadState',0,0,16)>0
    self:readPlayerEnergy(ped)
    self:readNativeState(ped)
    s.health=logic.displayHealth(s.rawHealth or math.max(0,s.health-1),self.server and self.server.horizon)
    if s.health<=0 then s.alive=false end
    if call('isCharInAnyCar', false, ped) then
        local car = call('storeCarCharIsInNoSave', 0, ped)
        if car ~= 0 and call('doesVehicleExist', false, car) then
            s.vehicle = car
            s.driver = call('getDriverOfCar', -1, car) == ped
            s.model = call('getCarModel', 0, car)
            s.boat = boatModels[s.model] or false
            -- Seated peds have no swim task. Require both the vehicle's water
            -- state and the player's position below the water surface; boats
            -- can report in-water while their occupants are above it.
            if call('isCarInWater', false, car) then
                local waterHeight=call('getWaterHeightAtCoords', s.z, s.x, s.y, false)
                s.underwater=s.underwater or s.z<waterHeight
            end
            s.speed = math.max(0, call('getCarSpeed', 0, car)) * 2.2369362921
            s.vehicleHealth = call('getCarHealth', 0, car)
            -- Observe the current car's actual lock state; /pvlock may change it.
            -- Do not send a lock command merely to populate a dashboard icon.
            local lock=call('getCarDoorLockStatus',-1,car)
            if lock>=0 and lock<=7 and lock==math.floor(lock) then
                s.locked=lock==2 or lock==3 or lock==4 or lock==5 or lock==7
                s.lockState=lock
            end
            local gxt = call('getNameOfVehicleModel', '', s.model)
            s.vehicleName = gxt ~= '' and call('getGxtText', gxt, gxt) or 'Vehicle'
        end
    end
    return s
end

function M:stopCruise()
    self.cruise.active = false
    if self.keysOverridden then setGameKeyState(16, 0); self.keysOverridden=false end
end

function M:toggleCruise(target)
    local s = self.sample
    if not s.vehicle or not s.driver or s.boat then self.notify('Cruise control needs a road vehicle that you are driving.'); return end
    if self.cruise.active and not target then self:stopCruise(); self.notify('Cruise control off.'); return end
    self.cruise.active, self.cruise.target = true, logic.clamp(target or math.floor(s.speed + 0.5), 1, 200)
    self.notify('Cruise control: ' .. self.cruise.target .. ' mph. Brake or press the toggle key to cancel.')
end

function M:drive(blocked)
    local s = self.sample
    if not self.cruise.active then return end
    if blocked or not s.ready or not s.alive or not s.vehicle or not s.driver or s.boat then self:stopCruise(); return end
    if call('isKeyDown', false, 83) or call('isKeyDown', false, 32) or call('getPadState',0,0,14) > 0 or call('getPadState',0,0,6) > 0 then
        self:stopCruise(); return
    end
    -- Use the normal accelerator; preserve steering, traction and the vehicle's natural top speed.
    setGameKeyState(16, logic.cruiseThrottle(s.speed, self.cruise.target))
    self.keysOverridden = true
end

function M:siren()
    local s = self.sample
    if s.vehicle and s.driver then switchCarSiren(s.vehicle, not isCarSirenOn(s.vehicle)) end
end

function M:reload()
    local s = self.sample
    if self.reloadGuard.active then return end
    if not s.ready or not s.alive or s.vehicle or not s.weapon or s.weapon<22 or s.weapon>34 then return end
    if not self.server or not self.server.horizon then
        self.notify('Reload animation is available on Horizon Roleplay.')
        return
    end
    -- The server owns the animation and eligibility checks; never write ammo.
    return '/reload 2'
end

function M:cleanup() self:stopCruise();self.reloadGuard:clear() end
M.call = call
return M

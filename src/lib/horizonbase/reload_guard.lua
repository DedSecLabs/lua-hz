-- Only the normal weapon-cycle control is gated; animation/ammo remain server-owned.
local M={};M.__index=M
local names={'buddy_crouchreload','buddy_reload','colt45_crouchreload','colt45_reload',
    'sawnoff_reload','python_crouchreload','python_reload','RIFLE_crouchload','RIFLE_load',
    'CrouchReload','Silence_reload','TEC_crouchreload','TEC_reload','UZI_crouchreload','UZI_reload'}
local function invoke(name,...)
    if type(_G[name])~='function' then return end
    local ok,value=pcall(_G[name],...)
    if ok then return value end
end
function M.new()return setmetatable({},M)end
function M:begin(sample)
    if self.active or type(_G.setPlayerWeaponsScrollable)~='function' then return end
    local ok,memory=pcall(require,'memory')
    if not ok or type(memory.getuint8)~='function' then return end
    -- GTA SA 1.0 US CPad[0], bDisablePlayerCycleWeapon (Plugin-SDK).
    -- Observe the prior restriction; restore through the normal SCM API only.
    local read,disabled=pcall(memory.getuint8,0xB73458+0x11D,false)
    if not read or (disabled~=0 and disabled~=1) then return end
    self.active=true;self.restoreEnabled=disabled==0;self.handle=PLAYER_HANDLE
    self.ped=PLAYER_PED;self.playerId=sample.playerId;self.weapon=sample.weapon
    self.started=getGameTimer();self.anim=nil;self.seen=false;self.observedAt=nil
    setPlayerWeaponsScrollable(self.handle,false)
end
function M:clear()
    if self.active and self.restoreEnabled then invoke('setPlayerWeaponsScrollable',self.handle,true)end
    self.active=false;self.restoreEnabled=nil;self.anim=nil;self.seen=false
end
function M:onAnimation(playerId,name)
    -- The next own-player animation after our command is its server-selected variant.
    if self.active and playerId==self.playerId and not self.seen and
        type(name)=='string' and #name>0 and #name<=64 then
        self.anim=name;self.observedAt=getGameTimer()
    end
end
function M:onClear(playerId)
    -- A server may clear the previous task before applying its reload animation.
    if self.active and playerId==self.playerId and (self.anim or self.seen) then self:clear()end
end
function M:update(sample,focused)
    if not self.active then return end
    local now=getGameTimer()
    if not focused or not sample.ready or not sample.alive or sample.vehicle or
        PLAYER_PED~=self.ped or sample.weapon~=self.weapon or now<self.started or now-self.started>15000 then
        self:clear();return
    end
    if not self.anim then
        for _,name in ipairs(names)do
            if invoke('isCharPlayingAnim',self.ped,name)==true then self.anim=name;break end
        end
    end
    local playing=self.anim and invoke('isCharPlayingAnim',self.ped,self.anim)==true
    if playing then
        self.seen=true
        local progress=invoke('getCharAnimCurrentTime',self.ped,self.anim)
        if type(progress)=='number' and progress>=.999 and progress<=1 then self:clear();return end
    elseif self.seen or now-self.started>=2500 and
        (not self.observedAt or now-self.observedAt>=750) then self:clear();return end
    -- Keep keyboard, mouse-wheel and controller cycle bindings gated each frame.
    invoke('setPlayerWeaponsScrollable',self.handle,false)
end
return M

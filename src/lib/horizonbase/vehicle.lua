-- Observes ordinary server replies; never changes native vehicle fields.
local logic=require 'horizonbase.logic'
local M={};M.__index=M
local parts={engine=true,lights=true,window=true,hood=true,trunk=true}
local replies={
    ['Vehicle engine turned on.']={'engine',true},['Vehicle engine turned off.']={'engine',false},
    ['Vehicle lights successfully turned on.']={'lights',true},['Vehicle lights successfully turned off.']={'lights',false},
    ['Vehicle hood successfully opened.']={'hood',true},['Vehicle hood successfully closed.']={'hood',false},
    ['Vehicle trunk successfully opened.']={'trunk',true},['Vehicle trunk successfully closed.']={'trunk',false},
}
function M.command(part)if parts[part]then return '/car '..part end end
function M.new(clock,notify)
    local self=setmetatable({now=clock,notify=notify or function()end,epoch=0},M);self:reset();return self
end
function M:reset()
    self.epoch=self.epoch+1;self.current=nil;self.pending=nil
end
function M:update(sample,eligible)
    local id=sample.networkVehicleId
    if not sample.ready or not sample.alive or not sample.vehicle or type(id)~='number' or id<0 or id>1999 or id~=math.floor(id) then
        if self.current or self.pending then self:reset()end;return
    end
    local c=self.current
    if not c or c.handle~=sample.vehicle or c.id~=id or c.model~=sample.model then
        self:reset();c={handle=sample.vehicle,id=id,model=sample.model,name=sample.vehicleName or 'Vehicle',
            entered=self.now(),states={},epoch=self.epoch};self.current=c
    end
    if c.driver~=nil and c.driver~=sample.driver then self.pending=nil;c.states={}end
    c.driver=sample.driver==true
    for part,state in pairs(c.states)do if self.now()-state.at>=60000 then c.states[part]=nil end end
    if not eligible then self.pending=nil
    elseif self.pending and self.now()>=self.pending.expires then
        local gui=self.pending.gui;self.pending=nil
        if gui then self.notify('Vehicle change was not confirmed.','error','vehicle-controls')end
    end
end
function M:token()return self.current and self.current.epoch end
function M:onOutgoing(command,gui)
    local part=type(command)=='string' and command:lower():match('^/car%s+([a-z]+)%s*$')
    local c=self.current
    if not parts[part] or not c or not c.driver then self.pending=nil;return end
    local now=self.now()
    if self.pending and self.pending.part==part and self.pending.epoch==c.epoch and now-self.pending.at<250 then return end
    self.pending={part=part,epoch=c.epoch,at=now,expires=now+8000,gui=gui==true}
end
function M:onMessage(text,actor)
    if type(text)~='string' or #text>512 then return end
    local c=self.current;if not c then return end
    local clean=logic.strip(text):match('^%s*(.-)%s*$')
    local owner,name=require('horizonbase.observations').ownership(clean)
    if owner and self.now()-c.entered<=4000 and name:lower()==c.name:lower()then
        if c.ownership and c.ownership~=owner then c.conflict=true;c.ownership=nil
        elseif not c.conflict then c.ownership=owner end
    end
    local p=self.pending
    if not p or p.epoch~=c.epoch or not c.driver or self.now()>=p.expires then return end
    local response=replies[clean]
    if p.part=='window' and type(actor)=='string' and #actor<=64 then
        actor=actor:gsub('_',' ')
        if clean=='* '..actor..' rolls down their window and looks around.' then response={'window',true}
        elseif clean=='* '..actor..' quickly looks around and rolls up their vehicle window.' then response={'window',false}end
    end
    if response and response[1]==p.part then
        c.states[p.part]={value=response[2],at=self.now()};self.pending=nil
        if p.gui then self.notify('Vehicle updated.','success','vehicle-controls')end
    end
end
function M:state(part)
    local state=self.current and self.current.states[part]
    if state and self.now()-state.at<60000 then return state.value end
end
return M

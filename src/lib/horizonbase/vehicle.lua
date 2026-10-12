-- Session-only observations of ordinary vehicle commands; no native state writes.
local logic=require 'horizonbase.logic'
local M={};M.__index=M
local parts={engine=true,lights=true,window=true,hood=true,trunk=true}
local replies={
 ['Vehicle engine turned on.']={'engine',true},['Vehicle engine turned off.']={'engine',false},
 ['Vehicle lights successfully turned on.']={'lights',true},['Vehicle lights successfully turned off.']={'lights',false},
 ['Vehicle hood successfully opened.']={'hood',true},['Vehicle hood successfully closed.']={'hood',false},
 ['Vehicle trunk successfully opened.']={'trunk',true},['Vehicle trunk successfully closed.']={'trunk',false},
}
local rejections={
 ["This command can't be used in this vehicle."]='This control is unavailable for this vehicle.',
 ["You can't open the window in these type of vehicles."]='This vehicle has no usable window.',
 ["You can't do this while you are inside a vehicle."]='Exit the vehicle first.',
 ["You can't check the status of the trunk if it's closed! /car trunk to open it."]='Open the trunk before viewing its contents.',
 ['You are not near any vehicle that you own.']='No personal vehicle nearby.',
 ['You are not near any vehicle that your family owns.']='No family vehicle nearby.',
}
function M.command(part)if parts[part]then return '/car '..part end end
function M.new(clock,notify)
 local self=setmetatable({now=clock,notify=notify or function()end,epoch=0},M);self:reset();return self
end
function M:reset()
 self.epoch=self.epoch+1;self.current=nil;self.pending=nil;self.cargo=nil;self.sample=nil
end
local function moved(a,b)
 if not a or not b or not a.x or not b.x then return false end
 return (a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2>9
end
function M:update(sample,eligible)
 if not sample.ready or not sample.alive then self:reset();return end
 local id=sample.networkVehicleId
 local valid=sample.vehicle and type(id)=='number' and id>=0 and id<=1999 and id==math.floor(id)
 local c=self.current
 if valid then
  if not c or c.handle~=sample.vehicle or c.id~=id or c.model~=sample.model then
   self:reset();c={handle=sample.vehicle,id=id,model=sample.model,name=sample.vehicleName or 'Vehicle',
    entered=self.now(),states={},unavailable={},epoch=self.epoch};self.current=c
  end
  if c.driver~=nil and c.driver~=sample.driver then self.pending=nil;c.states={}end
  c.driver=sample.driver==true
  for part,state in pairs(c.states)do if self.now()-state.at>=60000 then c.states[part]=nil end end
 elseif c then self:reset()end
 self.sample=sample
 if self.cargo and (sample.vehicle or moved(self.cargo.anchor,sample) or self.now()-self.cargo.at>=60000)then self.cargo=nil end
 if not eligible or self.pending and (self.pending.epoch~=self.epoch or moved(self.pending.anchor,sample))then self.pending=nil end
 local p=self.pending
 if p and p.draft and p.lastLine and self.now()-p.lastLine>=750 then
  self.cargo={title=p.draft.title,rows=p.draft.rows,anchor=p.anchor,at=self.now()};self.pending=nil
 elseif p and self.now()>=p.expires then
  self.pending=nil
  if p.gui then self.notify('Vehicle change was not confirmed.','error','vehicle-controls')end
 end
end
function M:token()return self.epoch end
function M:available(part)
 if self.pending then return false,'Waiting for the server' end
 if part=='trunk' then return true,'Open / close nearby trunk' end
 local c=self.current
 if not c or not c.driver then return false,'Enter as driver' end
 if c.unavailable[part]then return false,c.unavailable[part]end
 return parts[part]==true,'Toggle '..part
end
function M:onOutgoing(command,gui)
 local lower=type(command)=='string' and command:lower() or ''
 local part=lower:match('^/car%s+([a-z]+)%s*$')
 if lower:match('^/trunkbalance%s*$')then part='cargo' end
 local c=self.current;local s=self.sample or {}
 if part=='cargo' and s.vehicle or part~='cargo' and not parts[part] or
  part~='cargo' and part~='trunk' and (not c or not c.driver) then self.pending=nil;return end
 local now=self.now()
 if self.pending and self.pending.part==part and self.pending.epoch==self.epoch and now-self.pending.at<250 then return end
 self.pending={part=part,epoch=self.epoch,at=now,expires=now+8000,gui=gui==true,
  anchor=not c and {x=s.x,y=s.y,z=s.z}or nil}
 if part=='cargo'then self.cargo=nil end
end
function M:onMessage(text,actor)
 if type(text)~='string' or #text>512 then return end
 local clean=logic.strip(text):match('^%s*(.-)%s*$');local c=self.current
 local owner,name=require('horizonbase.observations').ownership(clean)
 if c and owner and self.now()-c.entered<=4000 and name:lower()==c.name:lower()then
  if c.ownership and c.ownership~=owner then c.conflict=true;c.ownership=nil
  elseif not c.conflict then c.ownership=owner end
 end
 local p=self.pending
 if not p or p.epoch~=self.epoch or self.now()>=p.expires then return end
 if rejections[clean]then
  self.pending=nil
  if c and (clean=="This command can't be used in this vehicle." or clean=="You can't open the window in these type of vehicles.")then
   c.unavailable[p.part]=rejections[clean];c.states[p.part]=nil
  end
  if p.gui then self.notify(rejections[clean],'error','vehicle-controls')end
  return
 end
 if p.part=='cargo'then
  local title=clean:match('^%*%*%* (.+) Trunk %*%*%*$')
  if title then p.draft={title=title,rows={}};p.lastLine=self.now()
  elseif p.draft and (#p.draft.rows<16)and (clean:match('^Slot %d+: .+$') or clean:match('^Pot: %d+ grams$') or clean:match('^Crack: %d+ grams$'))then
   p.draft.rows[#p.draft.rows+1]=clean;p.lastLine=self.now()
  end
  return
 end
 local response=replies[clean]
 if p.part=='window' and type(actor)=='string' and #actor<=64 then
  actor=actor:gsub('_',' ')
  if clean=='* '..actor..' rolls down their window and looks around.'then response={'window',true}
  elseif clean=='* '..actor..' quickly looks around and rolls up their vehicle window.'then response={'window',false}end
 end
 if response and response[1]==p.part then
  if c then c.states[p.part]={value=response[2],at=self.now()}end
  self.pending=nil
  if p.gui then self.notify('Vehicle updated.','success','vehicle-controls')end
 end
end
function M:state(part)
 local state=self.current and self.current.states[part]
 if state and self.now()-state.at<60000 then return state.value end
end
return M

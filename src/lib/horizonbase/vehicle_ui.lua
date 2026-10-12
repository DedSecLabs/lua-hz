local M={};M.__index=M
function M.new(im,ui,vehicle,server,perform)
 return setmetatable({im=im,ui=ui,vehicle=vehicle,server=server,perform=perform,open=im.new.bool(false),page=1,cursor=false},M)
end
function M:reset()self.open[0]=false;self.notice=nil;self.cursor=false end
function M:submit(kind,arg)
 local ok,err=self.perform(kind,arg)
 if ok then self.notice=nil else self.notice=err or 'Action unavailable.'end
end
-- Fit between the actual upper HUD and the lower HUD/notice stack.
function M:layout(w,h)
 local overlay=self.ui.overlay;local top=12;local bottom=h-20;local preferred=self.ui.scale
 if overlay and overlay.game.sample.ready then
  local upper=overlay:hudGeometry(w,h)
  top=upper.y+upper.height+12*upper.scale
  for _,panel in ipairs(overlay:lowerHudBounds(w,h))do bottom=math.min(bottom,panel.y-114*upper.scale)end
  bottom=math.min(bottom,h-114*upper.scale)
 end
 local available=bottom-top
 -- Extreme custom HUD placements use a viewport-safe fallback.
 if available<160 then top=12;bottom=h-20;available=bottom-top end
 local S=math.min(preferred,(w-24)/360,available/340)
 return {x=w-12-360*S,y=top,width=360*S,height=340*S,scale=S}
end
function M:tile(label,hint,icon,x,y,S,enabled,kind,arg)
 local im=self.im;im.SetCursorPos(im.ImVec2(x*S,y*S));local p=im.GetCursorScreenPos()
 local clicked=im.InvisibleButton(label..'##vehicleAction',im.ImVec2(156*S,56*S));local dl=im.GetWindowDrawList()
 local hover=enabled and im.IsItemHovered()
 dl:AddRectFilled(p,im.ImVec2(p.x+156*S,p.y+56*S),hover and im.U32(.25,.22,.16,1)or im.U32(.15,.16,.18,1),6*S)
 local tint=enabled and im.U32(1,.62,0,1)or im.U32(.65,.67,.70,1)
 local path=icon=='track' and 'ui-v0212/radar.png'or icon=='lock' and 'dashboard-v031/car-door-lock.png'or 'vehicle-v040/'..icon..'.png'
 local tex=self.ui.overlay and self.ui.overlay:texture(path)
 if tex then dl:AddImage(tex,im.ImVec2(p.x+10*S,p.y+8*S),im.ImVec2(p.x+36*S,p.y+34*S),im.ImVec2(0,0),im.ImVec2(1,1),tint)end
 dl:AddTextFontPtr(im.GetFont(),14*S,im.ImVec2(p.x+43*S,p.y+13*S),enabled and im.U32(.94,.95,.97,1)or im.U32(.65,.67,.70,1),label)
 local width=136*S;local size=12*S
 while #hint>0 and im.CalcTextSize(hint).x*size/im.GetFontSize()>width do hint=hint:sub(1,-2)end
 dl:AddTextFontPtr(im.GetFont(),size,im.ImVec2(p.x+10*S,p.y+43*S),im.U32(.68,.70,.74,1),hint)
 if clicked and enabled and self.cursor then self:submit(kind,arg)end
end
function M:draw()
 local im=self.im;self.ui:theme();local w,h=getScreenResolution();local box=self:layout(w,h);local S=box.scale
 im.GetIO().FontGlobalScale=S*15/(im.FontBaseSize or 15)
 im.SetNextWindowSize(im.ImVec2(box.width,box.height),im.Cond.Always)
 im.SetNextWindowPos(im.ImVec2(box.x,box.y),im.Cond.Always)
 local flags=im.WindowFlags.NoTitleBar+im.WindowFlags.NoCollapse+im.WindowFlags.NoResize+im.WindowFlags.NoScrollbar+im.WindowFlags.NoNavInputs+im.WindowFlags.NoNavFocus
 if not self.cursor then flags=flags+im.WindowFlags.NoInputs end
 im.Begin('##LuaHZVehicle',self.open,flags)
 local ok,err=pcall(function()
  im.SetCursorPos(im.ImVec2(18*S,14*S));self.ui:title('Vehicle',im.ImVec4(1,.62,0,1))
  im.SetCursorPos(im.ImVec2(324*S,8*S));local closePos=im.GetCursorScreenPos()
  if im.InvisibleButton('##closeVehicle',im.ImVec2(24*S,24*S))and self.cursor then self:reset()end
  local dl=im.GetWindowDrawList();local closeIcon=self.ui.overlay and self.ui.overlay:texture('ui-v0212/x.png')
  if closeIcon then dl:AddImage(closeIcon,im.ImVec2(closePos.x+3*S,closePos.y+3*S),im.ImVec2(closePos.x+21*S,closePos.y+21*S),im.ImVec2(0,0),im.ImVec2(1,1),im.U32(.68,.70,.74,1))end
  local c=self.vehicle.current
  im.SetCursorPos(im.ImVec2(18*S,43*S));im.TextUnformatted(c and c.name or 'Nearby vehicle')
  im.SetCursorPos(im.ImVec2(18*S,64*S));im.TextDisabled(c and ((c.ownership=='personal' and 'Personal' or c.ownership=='family' and 'Family' or 'Ownership unknown')..' | '..(c.driver and 'Driver' or 'Passenger'))or 'Trunk and locks use the nearby vehicle.')
  for i,label in ipairs({'Controls','Trunk','My vehicles'})do
   local x=18+(i-1)*108;im.SetCursorPos(im.ImVec2(x*S,89*S));local pos=im.GetCursorScreenPos()
   if im.InvisibleButton(label..'##vehicleTab'..i,im.ImVec2(104*S,28*S))and self.cursor then self.page=i;self.notice=nil end
   local tint=self.page==i and im.U32(1,.62,0,1)or im.U32(.64,.66,.70,1);local width=im.CalcTextSize(label).x
   dl:AddTextFontPtr(im.GetFont(),14*S,im.ImVec2(pos.x+(104*S-width)/2,pos.y+6*S),tint,label)
   dl:AddLine(im.ImVec2(pos.x,pos.y+28*S),im.ImVec2(pos.x+104*S,pos.y+28*S),tint,self.page==i and 3*S or S)
  end
  if self.page==1 then
   for i,row in ipairs({{'Engine','engine'},{'Lights','lights'},{'Window','window'},{'Hood','hood'},{'Trunk','trunk'}})do
    local part=row[2];local enabled,hint=self.vehicle:available(part);local value=self.vehicle:state(part)
    if not enabled then hint=self.vehicle.pending and '' or c and c.unavailable[part] and 'Not available' or 'Inside vehicle only'
    elseif value~=nil then hint=(part=='window' or part=='hood' or part=='trunk')and(value and 'Open' or 'Closed')or(value and 'On' or 'Off')end
    local y=part=='hood' and 252 or 128+math.floor((i-1)/2)*62
    self:tile(row[1],hint,part,18+((i-1)%2)*168,y,S,enabled,'vehicleControl',part)
   end
   self:tile('Lock / unlock','Personal or family','lock',186,190,S,not self.vehicle.pending,'lock')
  elseif self.page==2 then
   self:tile('Trunk','Open / close','trunk',18,128,S,not self.vehicle.pending,'vehicleControl','trunk')
   local onFoot=not(self.vehicle.sample or {}).vehicle
   self:tile('Contents',onFoot and 'Refresh contents' or 'Exit vehicle first','garage',186,128,S,onFoot and not self.vehicle.pending,'cargo')
   im.SetCursorPos(im.ImVec2(18*S,202*S));im.BeginChild('##trunkContents',im.ImVec2(324*S,100*S),false)
   local cargoOk,cargoErr=pcall(function()
    local cargo=self.vehicle.cargo
    if cargo then
     im.TextWrapped(cargo.title..' — Trunk')
     for _,line in ipairs(cargo.rows)do im.TextUnformatted(line)end
    else im.TextWrapped(self.vehicle.pending and self.vehicle.pending.part=='cargo' and 'Loading contents...'or 'On foot, open the nearby trunk and click Contents.')end
   end)
   im.EndChild();if not cargoOk then error(cargoErr)end
  else
   self:tile('Storage','Spawn / store','garage',18,128,S,true,'storage')
   self:tile(self.server.track.active and 'Stop tracking' or 'Track vehicle',self.server.track.active and 'Stop updates' or 'Spawned vehicles','track',186,128,S,true,'track')
   im.SetCursorPos(im.ImVec2(18*S,205*S));im.TextWrapped(self.server.track.location and 'Last location: '..self.server.track.location or 'Choose your vehicle in the server menu.')
   im.SetCursorPos(im.ImVec2(18*S,252*S));im.TextWrapped('Storage can spawn or store a vehicle. Check the selected row before confirming.')
  end
  im.SetCursorPos(im.ImVec2(18*S,322*S));im.TextDisabled(self.notice or 'Hold Alt to click | K / Esc closes')
 end)
 im.End();if not ok then error(err)end
end
return M

local palette=require 'horizonbase.palette'
local Status=require 'horizonbase.vehicle_status'
local M={};M.__index=M
local controls={{label='Engine',part='engine',key=69,badge='E'},{label='Lights',part='lights',key=76,badge='L'},
 {label='Window',part='window',key=79,badge='O'},{label='Doors',part='lock',key=85,badge='U'},
 {label='Hood',part='hood',key=72,badge='H'},{label='Trunk',part='trunk',key=66,badge='B'}}
function M.new(im,ui,vehicle,server,perform)
 return setmetatable({im=im,ui=ui,vehicle=vehicle,server=server,perform=perform,open=im.new.bool(false),page=1,cursor=false},M)
end
function M:reset()self.open[0]=false;self.notice=nil;self.cursor=false;self.queued=false;self.busyAt=nil;self.busyKind=nil;self.busyArg=nil end
function M:submit(kind,arg)
 local ok,err=self.perform(kind,arg)
 if ok then self.notice=nil;self.queued=true;self.busyAt=getGameTimer();self.busyKind=kind;self.busyArg=arg else self.notice=err or 'Action unavailable.'end
end
function M:reserved(key)
 local p=self.ui.prefs
 return p and ((p.keybinds.settingsPanel==key and (p.modifiers.settingsPanel or 0)==0)or
  (p.keybinds.vehicleMenu==key and (p.modifiers.vehicleMenu or 0)==0))
end
-- Retain normal labels while commands are quick; delayed progress is shown once.
function M:busy()
 local p=self.vehicle.pending
 if not(p or self.queued)then self.busyAt=nil;self.busyKind=nil;self.busyArg=nil;return false,false end
 local now=getGameTimer();local since=self.busyAt
 if p then
  local own=p.gui==true and ((self.busyKind=='vehicleControl' and self.busyArg==p.part)or(self.busyKind=='cargo' and p.part=='cargo'))
  if not own then since=p.at end
 end
 if not since then since=now;self.busyAt=now end
 return true,now-since>=1000,p and p.part or self.busyKind
end
function M:actions()
 local list={};local pending=self:busy()
 local sample=self.vehicle.sample or {};local c=self.vehicle.current
 local function control(spec)
  local part=spec.part;local state=Status.describe(self.vehicle,sample,part)
  local enabled,reason
  if part=='lock' then enabled=not pending;reason='Personal / family nearby'
  else enabled,reason=self.vehicle:available(part)end
  enabled=enabled and not pending
  local hint=state.text
  if not sample.vehicle then
   -- On foot these describe available actions, not an identified car's live state.
   if part=='lock' then hint='Lock / unlock nearby'
   elseif part=='trunk' then hint='Open / close nearby'
   else hint='Driver only'end
  elseif not enabled then
   if pending then hint=state.text -- Keep a known value while another action awaits confirmation.
   elseif not state.known then hint='Unavailable'
   else hint=state.text..' | Driver only'end
  end
  list[#list+1]={label=spec.label,hint=hint,path=state.path,token=state.token,enabled=enabled,
   key=spec.key,badge=not self:reserved(spec.key)and spec.badge or nil,kind=part=='lock' and 'lock' or 'vehicleControl',arg=part~='lock' and part or nil,
   reason=not enabled and (pending and 'Waiting for the server' or reason)or nil}
 end
 if self.page==1 then for _,spec in ipairs(controls)do control(spec)end
 elseif self.page==2 then
  control(controls[6])
  list[#list+1]={label='Trunk balance',hint=not sample.vehicle and 'Show contents' or 'Exit vehicle first',path='vehicle-v040/garage.png',token='muted',
   enabled=not sample.vehicle and not pending,key=67,badge=not self:reserved(67)and 'C' or nil,kind='cargo'}
 else
  list[#list+1]={label='Storage',hint='Spawn / store',path='vehicle-v042/garage.png',token='muted',enabled=not pending,key=86,badge=not self:reserved(86)and 'V' or nil,kind='storage'}
  local active=self.server.track.active
  list[#list+1]={label=active and 'Stop tracking' or 'Track vehicle',hint=active and 'Active' or 'Inactive',path='ui-v0212/radar.png',token=active and 'accent' or 'muted',
   enabled=not pending,key=82,badge=not self:reserved(82)and 'R' or nil,kind='track'}
 end
 return list
end
function M:ownsKey(key)
 if self:reserved(key)then return false end
 if key==219 or key==221 then return true end
 for _,a in ipairs(self:actions())do if a.key==key then return true end end
 return false
end
function M:shortcut(key)
 if not self:ownsKey(key)then return false end
 if key==219 or key==221 then self.page=(self.page-1+(key==219 and -1 or 1))%3+1;self.notice=nil;return true end
 for _,a in ipairs(self:actions())do
  if a.key==key then if a.enabled then self:submit(a.kind,a.arg)end;return true end
 end
 return false
end
-- Match the dashboard's physical width and right edge without enlarging text.
function M:layout(w,h)
 local overlay=self.ui.overlay;local top=12;local bottom=h-20;local preferred=self.ui.scale
 local target,upper
 if overlay and overlay.game.sample.ready then
  local lower;upper,lower=overlay:vehicleMenuGeometry(w,h);target=lower
  if overlay.game.sample.vehicle and overlay.config.settings.vdb>0 then target=overlay:lowerHudBounds(w,h)[1]or lower end
  top=upper.y+upper.height+12*upper.scale
  bottom=math.min(bottom,lower.y-114*upper.scale)
  bottom=math.min(bottom,h-114*upper.scale)
 end
 local available=bottom-top
 if available<160 then top=12;bottom=h-20;available=bottom-top end
 local S=math.min(preferred,(w-24)/448,available/340)
 local width=math.min(target and target.width or 448*S,w-24)
 S=math.min(S,width/360) -- A tiny custom HUD cannot squeeze the two-column labels.
 local x=target and target.x or w-12-width
 x=math.max(12,math.min(x,w-12-width))
 if overlay and upper and overlay.game.sample.underwater and overlay.config.settings.oxygen then
  for _,panel in ipairs(overlay:lowerHudBounds(w,h))do
   if top+340*S>panel.y-114*upper.scale then x=math.max(12,math.min(x,panel.x-12*S-width))end
  end
 end
 return {x=x,y=top,width=width,height=340*S,scale=S,logicalWidth=width/S}
end
function M:keycap(dl,key,x,y,S)
 local im=self.im;local font=im.GetFont();local size=11*S
 local factor=size/font.FontSize;local pen=0;local left,top,right,bottom
 -- Optical centering: ignore the advance's trailing bearing and font line gap.
 for i=1,#key do
  local g=font:FindGlyph(key:byte(i))
  if g~=nil then
   if g.X1>g.X0 and g.Y1>g.Y0 then
    left=math.min(left or math.huge,pen+g.X0);right=math.max(right or -math.huge,pen+g.X1)
    top=math.min(top or math.huge,g.Y0);bottom=math.max(bottom or -math.huge,g.Y1)
   end
   pen=pen+g.AdvanceX
  end
 end
 if not left then
  local bounds=im.CalcTextSize(key);left=0;top=0;right=bounds.x/factor*size/im.GetFontSize();bottom=font.FontSize
 end
 local width=math.ceil(math.max(20*S,(right-left)*factor+10*S));local face=17*S
 dl:AddRectFilled(im.ImVec2(x,y+2*S),im.ImVec2(x+width,y+19*S),palette.u32(im,'border'),4*S)
 dl:AddRectFilled(im.ImVec2(x,y),im.ImVec2(x+width,y+face),palette.u32(im,'button'),4*S)
 local tx=math.floor(x+(width-(right-left)*factor)/2-left*factor+.5)
 local ty=math.floor(y+(face-(bottom-top)*factor)/2-top*factor+.5)
 dl:AddTextFontPtr(font,size,im.ImVec2(tx,ty),palette.u32(im,'text'),key)
 return width
end
function M:tile(a,x,y,S,tileWidth)
 local im=self.im;im.SetCursorPos(im.ImVec2(x*S,y*S));local p=im.GetCursorScreenPos()
 local clicked=im.InvisibleButton(a.label..'##vehicleAction',im.ImVec2(tileWidth*S,56*S));local dl=im.GetWindowDrawList()
 local hover=a.enabled and im.IsItemHovered()
 dl:AddRectFilled(p,im.ImVec2(p.x+tileWidth*S,p.y+56*S),hover and palette.u32(im,'cardHover')or palette.u32(im,'card'),6*S)
 if not a.enabled then dl:AddRect(p,im.ImVec2(p.x+tileWidth*S,p.y+56*S),palette.u32(im,'border'),6*S)end
 local tex=self.ui.overlay and self.ui.overlay:texture(a.path)
 if tex then dl:AddImage(tex,im.ImVec2(p.x+10*S,p.y+8*S),im.ImVec2(p.x+36*S,p.y+34*S),im.ImVec2(0,0),im.ImVec2(1,1),palette.u32(im,a.token))end
 dl:AddTextFontPtr(im.GetFont(),14*S,im.ImVec2(p.x+43*S,p.y+13*S),a.enabled and palette.u32(im,'text')or palette.u32(im,'muted'),a.label)
 local badge=a.enabled and a.badge;local width=(tileWidth-(badge and 48 or 20))*S;local size=12*S;local hint=a.hint
 if im.CalcTextSize(hint).x*size/im.GetFontSize()>width then
  while #hint>0 and im.CalcTextSize(hint..'...').x*size/im.GetFontSize()>width do hint=hint:sub(1,-2)end
  hint=hint..'...'
 end
 dl:AddTextFontPtr(im.GetFont(),size,im.ImVec2(p.x+10*S,p.y+39*S),palette.u32(im,a.token),hint)
 if badge then self:keycap(dl,badge,p.x+(tileWidth-30)*S,p.y+30*S,S)end
 if clicked and a.enabled and self.cursor then self:submit(a.kind,a.arg)end
end
function M:footer(dl,S)
 local im=self.im;im.SetCursorPos(im.ImVec2(18*S,315*S));local p=im.GetCursorScreenPos();local x=p.x
 if self.notice then dl:AddTextFontPtr(im.GetFont(),11*S,p,palette.u32(im,'muted'),self.notice);return end
 local _,waiting,kind=self:busy()
 if waiting and not(kind=='cargo' and self.page==2)then
  dl:AddTextFontPtr(im.GetFont(),12*S,p,palette.u32(im,'muted'),'Waiting for server...');return
 end
 local function text(value)
  dl:AddTextFontPtr(im.GetFont(),11*S,im.ImVec2(x,p.y+3*S),palette.u32(im,'muted'),value)
  x=x+im.CalcTextSize(value).x*11*S/im.GetFontSize()+7*S
 end
 if not self:reserved(219)and not self:reserved(221)then
  x=x+self:keycap(dl,'[',x,p.y,S)+3*S;x=x+self:keycap(dl,']',x,p.y,S)+5*S;text('Tabs')
 end
 x=x+self:keycap(dl,'Alt',x,p.y,S)+5*S;text('Mouse')
 x=x+self:keycap(dl,'Esc',x,p.y,S)+5*S;text('Close')
end
function M:draw()
 local im=self.im;self.ui:theme();local w,h=getScreenResolution();local box=self:layout(w,h);local S=box.scale;local W=box.logicalWidth;local inner=W-36;local tileWidth=(inner-12)/2
 im.GetIO().FontGlobalScale=S*15/(im.FontBaseSize or 15)
 im.SetNextWindowSize(im.ImVec2(box.width,box.height),im.Cond.Always)
 im.SetNextWindowPos(im.ImVec2(box.x,box.y),im.Cond.Always)
 local flags=im.WindowFlags.NoTitleBar+im.WindowFlags.NoCollapse+im.WindowFlags.NoResize+im.WindowFlags.NoScrollbar+im.WindowFlags.NoNavInputs+im.WindowFlags.NoNavFocus
 if not self.cursor then flags=flags+im.WindowFlags.NoInputs end
 im.Begin('##LuaHZVehicle',self.open,flags)
 local ok,err=pcall(function()
  im.SetCursorPos(im.ImVec2(18*S,14*S));self.ui:title('Vehicle',palette.vec4(im,'accent'))
  im.SetCursorPos(im.ImVec2((W-36)*S,8*S));local closePos=im.GetCursorScreenPos()
  if im.InvisibleButton('##closeVehicle',im.ImVec2(24*S,24*S))and self.cursor then self:reset()end
  local dl=im.GetWindowDrawList();local closeIcon=self.ui.overlay and self.ui.overlay:texture('ui-v0212/x.png')
  if closeIcon then dl:AddImage(closeIcon,im.ImVec2(closePos.x+3*S,closePos.y+3*S),im.ImVec2(closePos.x+21*S,closePos.y+21*S),im.ImVec2(0,0),im.ImVec2(1,1),palette.u32(im,'muted'))end
  local c=self.vehicle.current
  im.SetCursorPos(im.ImVec2(18*S,43*S));im.TextUnformatted(c and c.name or 'Nearby vehicle')
  im.SetCursorPos(im.ImVec2(18*S,64*S));im.TextDisabled(c and ((c.ownership=='personal' and 'Personal' or c.ownership=='family' and 'Family' or 'Ownership unknown')..' | '..(c.driver and 'Driver' or 'Passenger'))or 'Trunk and locks use the nearby vehicle.')
  for i,label in ipairs({'Controls','Trunk','My vehicles'})do
   local step=inner/3;local tabWidth=step-4;local x=18+(i-1)*step;im.SetCursorPos(im.ImVec2(x*S,89*S));local pos=im.GetCursorScreenPos()
   if im.InvisibleButton(label..'##vehicleTab'..i,im.ImVec2(tabWidth*S,28*S))and self.cursor then self.page=i;self.notice=nil end
   local tint=self.page==i and palette.u32(im,'accent')or palette.u32(im,'muted');local width=im.CalcTextSize(label).x*14*S/im.GetFontSize()
   dl:AddTextFontPtr(im.GetFont(),14*S,im.ImVec2(pos.x+(tabWidth*S-width)/2,pos.y+6*S),tint,label)
   dl:AddLine(im.ImVec2(pos.x,pos.y+28*S),im.ImVec2(pos.x+tabWidth*S,pos.y+28*S),tint,self.page==i and 3*S or S)
  end
  for i,a in ipairs(self:actions())do self:tile(a,18+((i-1)%2)*(tileWidth+12),128+math.floor((i-1)/2)*62,S,tileWidth)end
  if self.page==2 then
   im.SetCursorPos(im.ImVec2(18*S,202*S));im.BeginChild('##trunkContents',im.ImVec2(inner*S,100*S),false)
   local cargoOk,cargoErr=pcall(function()
    local cargo=self.vehicle.cargo
    local p=self.vehicle.pending
    local loading=p and p.part=='cargo' or self.queued and self.busyKind=='cargo'
    if loading then im.TextWrapped('Loading contents...')
    elseif cargo then im.TextWrapped(cargo.title..' - Trunk');for _,line in ipairs(cargo.rows)do im.TextUnformatted(line)end
    else im.TextWrapped('On foot, open the nearby trunk and show its balance.')end
   end)
   im.EndChild();if not cargoOk then error(cargoErr)end
  elseif self.page==3 then
   im.SetCursorPos(im.ImVec2(18*S,205*S));im.TextWrapped(self.server.track.location and 'Last location: '..self.server.track.location or 'Choose your vehicle in the server menu.')
   im.SetCursorPos(im.ImVec2(18*S,252*S));im.TextWrapped('Storage can spawn or store a vehicle. Check the selected row before confirming.')
  end
  self:footer(dl,S)
 end)
 im.End();if not ok then error(err)end
end
return M

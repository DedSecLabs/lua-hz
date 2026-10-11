local M={};M.__index=M
function M.new(im,ui,vehicle,server,perform)
    return setmetatable({im=im,ui=ui,vehicle=vehicle,server=server,perform=perform,open=im.new.bool(false),page=1},M)
end
function M:reset()self.open[0]=false;self.notice=nil end
function M:submit(kind,arg)
    local ok,err=self.perform(kind,arg)
    if ok then self:reset()else self.notice=err or 'Vehicle action unavailable.'end
end
function M:tile(label,hint,icon,x,y,S,enabled,kind,arg)
    local im=self.im;im.SetCursorPos(im.ImVec2(x*S,y*S));local p=im.GetCursorScreenPos()
    local clicked=im.InvisibleButton(label..'##vehicleAction',im.ImVec2(272*S,82*S));local dl=im.GetWindowDrawList()
    local hover=enabled and im.IsItemHovered()
    dl:AddRectFilled(p,im.ImVec2(p.x+272*S,p.y+82*S),hover and im.U32(.25,.22,.16,1)or im.U32(.15,.16,.18,1),8*S)
    local tint=enabled and im.U32(1,.62,0,1)or im.U32(.65,.67,.70,1)
    local path=icon=='track' and 'ui-v0212/radar.png' or icon=='lock' and 'dashboard-v031/car-door-lock.png' or 'vehicle-v040/'..icon..'.png'
    local tex=self.ui.overlay and self.ui.overlay:texture(path)
    if tex then dl:AddImage(tex,im.ImVec2(p.x+14*S,p.y+15*S),im.ImVec2(p.x+46*S,p.y+47*S),im.ImVec2(0,0),im.ImVec2(1,1),tint)end
    dl:AddTextFontPtr(im.GetFont(),16*S,im.ImVec2(p.x+56*S,p.y+16*S),enabled and im.U32(.94,.95,.97,1)or im.U32(.65,.67,.70,1),label)
    dl:AddTextFontPtr(im.GetFont(),12*S,im.ImVec2(p.x+14*S,p.y+59*S),im.U32(.68,.70,.74,1),hint)
    if clicked and enabled then self:submit(kind,arg)end
end
function M:draw()
    local im=self.im;self.ui:theme();local w,h=getScreenResolution();local S=math.min(self.ui.scale,(w-24)/600,(h-24)/460)
    im.GetIO().FontGlobalScale=S*15/(im.FontBaseSize or 15)
    im.SetNextWindowSize(im.ImVec2(600*S,460*S),im.Cond.Always);im.SetNextWindowPos(im.ImVec2(w/2,h/2),im.Cond.Always,im.ImVec2(.5,.5))
    im.Begin('##LuaHZVehicle',self.open,im.WindowFlags.NoTitleBar+im.WindowFlags.NoCollapse+im.WindowFlags.NoResize+im.WindowFlags.NoScrollbar)
    local ok,err=pcall(function()
        im.SetCursorPos(im.ImVec2(22*S,18*S));self.ui:title('Vehicle',im.ImVec4(1,.62,0,1))
        im.SetCursorPos(im.ImVec2(565*S,10*S));local closePos=im.GetCursorScreenPos()
        if im.InvisibleButton('##closeVehicle',im.ImVec2(24*S,24*S))then self:reset()end
        local closeIcon=self.ui.overlay and self.ui.overlay:texture('ui-v0212/x.png')
        if closeIcon then im.GetWindowDrawList():AddImage(closeIcon,im.ImVec2(closePos.x+3*S,closePos.y+3*S),im.ImVec2(closePos.x+21*S,closePos.y+21*S),im.ImVec2(0,0),im.ImVec2(1,1),im.IsItemHovered()and im.U32(1,.62,0,1)or im.U32(.68,.70,.74,1))end
        local c=self.vehicle.current
        im.SetCursorPos(im.ImVec2(22*S,54*S));im.TextUnformatted(c and c.name or 'My vehicles')
        im.SetCursorPos(im.ImVec2(22*S,77*S));im.TextDisabled(c and ((c.ownership=='personal' and 'Personal vehicle' or c.ownership=='family' and 'Family vehicle' or 'Ownership not confirmed')..' | '..(c.driver and 'Driver' or 'Passenger'))or 'Storage and tracking are available while on foot.')
        local dl=im.GetWindowDrawList()
        for i,label in ipairs({'Controls','My vehicles'})do
            local x=22+(i-1)*278;im.SetCursorPos(im.ImVec2(x*S,105*S));local pos=im.GetCursorScreenPos()
            if im.InvisibleButton(label..'##vehicleTab'..i,im.ImVec2(272*S,30*S))then self.page=i;self.notice=nil end
            local tint=self.page==i and im.U32(1,.62,0,1)or im.U32(.64,.66,.70,1);local width=im.CalcTextSize(label).x
            dl:AddTextFontPtr(im.GetFont(),15*S,im.ImVec2(pos.x+(272*S-width)/2,pos.y+7*S),tint,label)
            dl:AddLine(im.ImVec2(pos.x,pos.y+31*S),im.ImVec2(pos.x+272*S,pos.y+31*S),tint,self.page==i and 3*S or S)
        end
        if self.page==1 then
            for i,row in ipairs({{'Engine','engine'},{'Lights','lights'},{'Window','window'},{'Hood','hood'},{'Trunk','trunk'}})do
                local part=row[2];local value=self.vehicle:state(part)
                local hint='Toggle '..part
                if value~=nil then hint='Last confirmed: '..((part=='window' or part=='hood' or part=='trunk') and (value and 'Open' or 'Closed')or(value and 'On' or 'Off'))end
                if not c or not c.driver then hint='Enter a vehicle as driver' end
                self:tile(row[1],hint,part,22+((i-1)%2)*284,150+math.floor((i-1)/2)*94,S,c and c.driver and not self.vehicle.pending,'vehicleControl',part)
            end
            self:tile('Lock / unlock','Personal or family vehicle nearby','lock',306,338,S,not self.vehicle.pending,'lock')
        else
            self:tile('Vehicle storage','Choose a vehicle to spawn or store','garage',22,150,S,true,'storage')
            self:tile(self.server.track.active and 'Stop tracking' or 'Track my vehicle',self.server.track.active and 'Stop periodic vehicle updates' or 'Choose a spawned personal vehicle','track',306,150,S,true,'track')
            im.SetCursorPos(im.ImVec2(22*S,252*S));im.TextUnformatted(self.server.track.active and 'Vehicle tracking is on' or 'Vehicle tracking is off')
            im.SetCursorPos(im.ImVec2(22*S,277*S));im.TextDisabled(self.server.track.location and 'Last location: '..self.server.track.location or 'Stored vehicles must be spawned before tracking.')
            im.SetCursorPos(im.ImVec2(22*S,314*S));im.TextWrapped('Storage uses the server menu. Selecting a spawned vehicle may store it; check its status before choosing.')
        end
        im.SetCursorPos(im.ImVec2(22*S,435*S));if self.notice then im.TextWrapped(self.notice)else im.TextDisabled('Escape closes this panel.')end
    end)
    im.End();if not ok then error(err)end
end
return M

local ffi=require 'ffi'
local M={};M.__index=M
function M.new(im,ui,server,perform,players)
    return setmetatable({im=im,ui=ui,server=server,perform=perform,players=players,
        open=im.new.bool(false),query=im.new.char[65](''),targets={},findMode=false},M)
end
function M:reset()
    self.open[0]=false;self.findMode=false;self.notice=nil;self.targets={};self.im.StrCopy(self.query,'')
end
function M:submit(kind,arg)
    local ok,err=self.perform(kind,arg)
    if ok then self.open[0]=false;self.notice=nil
    else self.notice=err or 'Action unavailable. Try again during gameplay.'end
end
function M:tile(label,hint,icon,x,y,width,S,action)
    local im=self.im;im.SetCursorPos(im.ImVec2(x*S,y*S));local p=im.GetCursorScreenPos()
    local clicked=im.InvisibleButton(label..'##quickAction',im.ImVec2(width*S,82*S))
    local hover=im.IsItemHovered();local dl=im.GetWindowDrawList()
    dl:AddRectFilled(p,im.ImVec2(p.x+width*S,p.y+82*S),hover and im.U32(.25,.22,.16,1) or im.U32(.15,.16,.18,1),8*S)
    local tex=self.ui.overlay and self.ui.overlay:texture('ui-v0212/'..icon..'.png')
    if tex then dl:AddImage(tex,im.ImVec2(p.x+14*S,p.y+16*S),im.ImVec2(p.x+42*S,p.y+44*S),im.ImVec2(0,0),im.ImVec2(1,1),im.U32(1,.62,0,1))end
    dl:AddTextFontPtr(im.GetFont(),16*S,im.ImVec2(p.x+54*S,p.y+16*S),im.U32(.94,.95,.97,1),label)
    dl:AddTextFontPtr(im.GetFont(),12*S,im.ImVec2(p.x+14*S,p.y+58*S),im.U32(.64,.66,.70,1),hint)
    if clicked then action()end
end
function M:draw()
    local im=self.im;self.ui:theme()
    local height=self.findMode and 400 or 280
    local w,h=getScreenResolution();local S=math.min(self.ui.scale,(w-24)/600,(h-24)/height)
    im.GetIO().FontGlobalScale=S*15/(im.FontBaseSize or 15)
    im.SetNextWindowSize(im.ImVec2(600*S,height*S),im.Cond.Always)
    im.SetNextWindowPos(im.ImVec2(w/2,h/2),im.Cond.Always,im.ImVec2(.5,.5))
    im.Begin('##LuaHZActions',self.open,im.WindowFlags.NoTitleBar+im.WindowFlags.NoCollapse+im.WindowFlags.NoResize+im.WindowFlags.NoScrollbar)
    local ok,err=pcall(function()
        im.SetCursorPos(im.ImVec2(22*S,18*S));self.ui:title('Quick Actions',im.ImVec4(1,.62,0,1))
        im.SetCursorPos(im.ImVec2(565*S,10*S))
        local closePos=im.GetCursorScreenPos()
        if im.InvisibleButton('##closeActions',im.ImVec2(24*S,24*S))then self:reset()end
        local closeIcon=self.ui.overlay and self.ui.overlay:texture('ui-v0212/x.png')
        if closeIcon then im.GetWindowDrawList():AddImage(closeIcon,im.ImVec2(closePos.x+3*S,closePos.y+3*S),im.ImVec2(closePos.x+21*S,closePos.y+21*S),im.ImVec2(0,0),im.ImVec2(1,1),im.IsItemHovered()and im.U32(1,.62,0,1)or im.U32(.68,.70,.74,1))end
        local server=self.server
        if self.findMode then
            im.SetCursorPos(im.ImVec2(22*S,54*S));im.TextUnformatted('Find player')
            im.SetCursorPos(im.ImVec2(22*S,76*S))
            im.TextDisabled('Detective job required.')
            im.SetCursorPos(im.ImVec2(22*S,98*S));im.TextDisabled('Name or ID')
            im.SetCursorPos(im.ImVec2(22*S,118*S))
            im.PushItemWidth(556*S);im.InputText('##findTarget',self.query,65);im.PopItemWidth()
            im.SetCursorPos(im.ImVec2(22*S,154*S))
            if im.Button('Find##submitTarget',im.ImVec2(74*S,28*S))then self:submit('find',ffi.string(self.query))end
            im.SetCursorPos(im.ImVec2(106*S,154*S))
            if im.Button('Back##actions',im.ImVec2(74*S,28*S))then self.findMode=false;self.notice=nil end
            im.SetCursorPos(im.ImVec2(482*S,154*S))
            im.PushStyleColor(im.Col.Button,im.ImVec4(.12,.13,.15,1))
            im.PushStyleColor(im.Col.ButtonHovered,im.ImVec4(.18,.19,.22,1))
            im.PushStyleColor(im.Col.ButtonActive,im.ImVec4(.22,.23,.27,1))
            im.PushStyleColor(im.Col.Text,im.ImVec4(.72,.74,.78,1))
            local refresh=im.Button('Refresh##quickPlayers',im.ImVec2(96*S,28*S))
            im.PopStyleColor(4)
            if refresh then self.targets=self.players()end
            im.SetCursorPos(im.ImVec2(22*S,198*S))
            im.BeginChild('##quickTargets',im.ImVec2(556*S,130*S),false)
            local childOk,childErr=pcall(function()
            local query=require('horizonbase.logic').normalizeName(ffi.string(self.query))
            for _,row in ipairs(self.targets)do
                if tostring(row.id)==query or require('horizonbase.logic').normalizeName(row.name):find(query,1,true)then
                    if im.Button(row.name..' ('..row.id..')##quickTarget'..row.id)then self:submit('find',{id=row.id,name=row.name})end
                end
            end
            end)
            im.EndChild();if not childOk then error(childErr)end
        else
            im.SetCursorPos(im.ImVec2(22*S,56*S))
            im.TextUnformatted(server.clearNavigation and 'Clearing navigation...' or server.checkpoint and 'Checkpoint active' or 'No checkpoint received')
            im.SetCursorPos(im.ImVec2(22*S,76*S))
            im.TextDisabled(server.find.active and (server.find.paused and 'Waiting for ' or 'Finding ')..server.find.name or 'Player finding is off')
            self:tile('Clear navigation','Also resets trackers and fares','map-pin-off',22,108,272,S,function()self:submit('clear')end)
            self:tile(server.find.active and 'Stop finding' or 'Find player',server.find.active and server.find.name or 'Select an online name or ID','search',306,108,272,S,function()
                if server.find.active then self:submit('stopFind')
                else self.findMode=true;self.notice=nil;self.targets=self.players()end
            end)
        end
        im.SetCursorPos(im.ImVec2(22*S,(height==400 and 340 or 226)*S))
        if self.notice then im.TextWrapped(self.notice)else im.TextDisabled('Escape closes this panel.')end
    end)
    im.End();if not ok then error(err)end
end
return M

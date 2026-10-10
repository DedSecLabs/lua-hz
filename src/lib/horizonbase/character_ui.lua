local M={};M.__index=M
function M.new(im,ui,server)
    return setmetatable({im=im,ui=ui,server=server,open=im.new.bool(false),tab=1},M)
end
function M:draw()
    local im=self.im;self.ui:theme()
    local w,h=getScreenResolution();local S=math.min(self.ui.scale,(w-24)/780,(h-24)/540)
    local c=self.server.character
    im.GetIO().FontGlobalScale=S*15/(im.FontBaseSize or 15)
    local overlay=self.ui.overlay;local sample=overlay and overlay.game.sample or {}
    local Live=require 'horizonbase.character_live'
    im.SetNextWindowSize(im.ImVec2(780*S,540*S),im.Cond.Always)
    im.SetNextWindowPos(im.ImVec2(w/2,h/2),im.Cond.Always,im.ImVec2(.5,.5))
    im.Begin('##LuaHZCharacter',self.open,im.WindowFlags.NoTitleBar+im.WindowFlags.NoCollapse+
        im.WindowFlags.NoResize+im.WindowFlags.NoScrollbar+im.WindowFlags.NoScrollWithMouse)
    im.SetWindowFontScale(1)
    im.SetCursorPos(im.ImVec2(22*S,18*S))
    self.ui:title('Character Status',im.ImVec4(1,.62,0,1))
    im.SetCursorPos(im.ImVec2(22*S,46*S));im.TextUnformatted(c.name or self.server.characterName or 'Your character')
    im.SetCursorPos(im.ImVec2(745*S,10*S))
    local p=im.GetCursorScreenPos()
    if im.InvisibleButton('##closeCharacter',im.ImVec2(25*S,25*S))then self.open[0]=false end
    local icon=self.ui.overlay and self.ui.overlay:texture('ui-v0212/x.png')
    if icon then
        im.GetWindowDrawList():AddImage(icon,im.ImVec2(p.x+3*S,p.y+3*S),im.ImVec2(p.x+22*S,p.y+22*S),
            im.ImVec2(0,0),im.ImVec2(1,1),im.IsItemHovered() and im.U32(1,.62,0,1) or im.U32(.68,.70,.74,1))
    end
    local origin=im.GetWindowPos();local dl=im.GetWindowDrawList()
    local skin=sample.ready and sample.skin
    local dimensions=skin and require('horizonbase.skin_portraits')[skin]
    local portrait=dimensions and overlay:texture('portraits-v0222/'..skin..'.png')
    dl:AddRectFilled(im.ImVec2(origin.x+22*S,origin.y+90*S),im.ImVec2(origin.x+164*S,origin.y+346*S),im.U32(.08,.09,.11,1),8*S)
    if portrait then
        local factor=math.min(126/dimensions[1],240/dimensions[2])*S
        local pw,ph=dimensions[1]*factor,dimensions[2]*factor
        local px,py=origin.x+93*S-pw/2,origin.y+218*S-ph/2
        dl:AddImage(portrait,im.ImVec2(px,py),im.ImVec2(px+pw,py+ph),im.ImVec2(0,0),im.ImVec2(1,1),im.U32(1,1,1,1))
    else
        im.SetCursorPos(im.ImVec2(30*S,190*S));im.PushItemWidth(124*S)
        im.TextWrapped('Preview unavailable');im.PopItemWidth()
    end
    im.SetCursorPos(im.ImVec2(22*S,356*S));im.TextDisabled(skin and 'Skin '..skin or 'Skin unavailable')
    im.SetCursorPos(im.ImVec2(22*S,382*S));im.TextDisabled(sample.ready and sample.playerId and 'Player ID '..sample.playerId or 'Player ID unavailable')
    im.SetCursorPos(im.ImVec2(22*S,414*S))
    if im.Button('Refresh',im.ImVec2(142*S,30*S)) then
        if self.server:requestStats() then self.notice=nil
        else self.notice='Refresh requires Horizon gameplay and a 10-second request gap.' end
    end
    local tabs={'Character','Work','Finances','Health','Inventory'}
    dl:AddLine(im.ImVec2(origin.x+184*S,origin.y+121*S),im.ImVec2(origin.x+758*S,origin.y+121*S),im.U32(.20,.21,.24,1),S)
    for i,label in ipairs(tabs)do
        im.SetCursorPos(im.ImVec2((184+(i-1)*116)*S,90*S))
        local row=im.GetCursorScreenPos()
        if im.InvisibleButton(label..'##characterTab'..i,im.ImVec2(110*S,30*S))then self.tab=i end
        local selected=self.tab==i
        local color=selected and im.U32(1,.62,0,1) or im.IsItemHovered() and im.U32(1,1,1,1) or im.U32(.64,.66,.70,1)
        local text=im.CalcTextSize(label)
        dl:AddText(im.ImVec2(row.x+(110*S-text.x)/2,row.y+(30*S-text.y)/2),color,label)
        if selected then dl:AddLine(im.ImVec2(row.x,row.y+31*S),im.ImVec2(row.x+110*S,row.y+31*S),color,3*S)end
    end
    im.SetCursorPos(im.ImVec2(184*S,134*S))
    im.BeginChild('##characterFields'..self.tab,im.ImVec2(574*S,341*S),false)
    local ok,err=pcall(function()
        if not c.updatedAt then
            im.TextWrapped((c.pending or self.server.statsRequested) and 'Requesting character stats...' or
                'Your stats will load after login. Click Refresh to request them now.')
            im.Spacing()
        end
        local group=require('horizonbase.character').groups[self.tab]
        for _,label in ipairs(group[2])do
            local pos=im.GetCursorScreenPos()
            im.TextDisabled(label);im.SameLine()
            im.SetCursorScreenPos(im.ImVec2(pos.x+164*S,pos.y))
            im.TextWrapped(Live.value(label,sample) or c.fields[label] or 'Not received')
        end
    end)
    im.EndChild()
    im.SetCursorPos(im.ImVec2(22*S,490*S))
    local status
    if c.pending or self.server.statsRequested then status='Refreshing...'
    elseif c.error then status=c.error
    elseif self.notice then status=self.notice
    elseif c.updatedAt then status=('Server snapshot updated %d seconds ago.%s'):format(
        math.max(0,math.floor((getGameTimer()-c.updatedAt)/1000)),c.partial and ' Some fields were not received.' or '')
    else status='Source: Horizon /stats. No stats are saved between sessions.' end
    im.TextWrapped(status)
    im.SetCursorPos(im.ImVec2(22*S,516*S));im.TextDisabled('Health, armor and cash are live. Other fields use /stats. Carried items use /inv.')
    im.End()
    if not ok then error(err) end
end
return M

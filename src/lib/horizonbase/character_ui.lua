local M={};M.__index=M
function M.new(im,ui,server)
    return setmetatable({im=im,ui=ui,server=server,open=im.new.bool(false),tab=1},M)
end
function M:draw()
    local im=self.im;self.ui:theme()
    local panelWidth=require('horizonbase.logic').menuWidth
    local contentWidth=panelWidth-206
    local w,h=getScreenResolution();local S=math.min(self.ui.scale,(w-24)/panelWidth,(h-24)/540)
    local c=self.server.character
    im.GetIO().FontGlobalScale=S*15/(im.FontBaseSize or 15)
    local overlay=self.ui.overlay;local sample=overlay and overlay.game.sample or {}
    local Live=require 'horizonbase.character_live'
    im.SetNextWindowSize(im.ImVec2(panelWidth*S,540*S),im.Cond.Always)
    im.SetNextWindowPos(im.ImVec2(w/2,h/2),im.Cond.Always,im.ImVec2(.5,.5))
    im.Begin('##LuaHZCharacter',self.open,im.WindowFlags.NoTitleBar+im.WindowFlags.NoCollapse+
        im.WindowFlags.NoResize+im.WindowFlags.NoScrollbar+im.WindowFlags.NoScrollWithMouse)
    im.SetWindowFontScale(1)
    im.SetCursorPos(im.ImVec2(22*S,18*S))
    self.ui:title('Character Status',im.ImVec4(1,.62,0,1))
    im.SetCursorPos(im.ImVec2(22*S,46*S));im.TextUnformatted(c.name or self.server.characterName or 'Your character')
    im.SetCursorPos(im.ImVec2((panelWidth-35)*S,10*S))
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
        if self.tab==6 and self.server:requestInfo('licenses') or self.tab~=6 and self.server:requestStats() then self.notice=nil
        else self.notice='Refresh requires Horizon gameplay and a 10-second request gap.' end
    end
    local tabs={'Character','Work','Finances','Health','Inventory','Licenses'}
    local tabStep=contentWidth/#tabs;local tabWidth=tabStep-6
    dl:AddLine(im.ImVec2(origin.x+184*S,origin.y+121*S),im.ImVec2(origin.x+(panelWidth-22)*S,origin.y+121*S),im.U32(.20,.21,.24,1),S)
    for i,label in ipairs(tabs)do
        im.SetCursorPos(im.ImVec2((184+(i-1)*tabStep)*S,90*S))
        local row=im.GetCursorScreenPos()
        if im.InvisibleButton(label..'##characterTab'..i,im.ImVec2(tabWidth*S,30*S))then
            self.tab=i
            if i==6 and not self.server.info.pages.licenses.updatedAt then self.server:requestInfo('licenses')end
        end
        local selected=self.tab==i
        local color=selected and im.U32(1,.62,0,1) or im.IsItemHovered() and im.U32(1,1,1,1) or im.U32(.64,.66,.70,1)
        local text=im.CalcTextSize(label)
        dl:AddText(im.ImVec2(row.x+(tabWidth*S-text.x)/2,row.y+(30*S-text.y)/2),color,label)
        if selected then dl:AddLine(im.ImVec2(row.x,row.y+31*S),im.ImVec2(row.x+tabWidth*S,row.y+31*S),color,3*S)end
    end
    im.SetCursorPos(im.ImVec2(184*S,134*S))
    im.BeginChild('##characterFields'..self.tab,im.ImVec2(contentWidth*S,341*S),false)
    local ok,err=pcall(function()
        if self.tab==6 then
            local page=self.server.info.pages.licenses
            for _,label in ipairs({"Driver's",'Pilot','Boating'})do
                im.TextUnformatted(label..' license');im.SameLine()
                im.TextDisabled(page.fields[label] or 'Not received')
            end
            im.Spacing()
            im.TextWrapped(page.loading and 'Refreshing licenses...' or page.error or
                (page.updatedAt and ('Updated %d seconds ago.'):format(math.max(0,math.floor((getGameTimer()-page.updatedAt)/1000))) or 'Click Refresh to load your licenses.'))
            return
        end
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
            if label=='Respect points' then
                local nextPos=im.GetCursorScreenPos()
                im.TextDisabled('Until next level');im.SameLine()
                im.SetCursorScreenPos(im.ImVec2(nextPos.x+164*S,nextPos.y))
                local respect=self.server.info and self.server.info.respect
                im.TextWrapped(respect and (respect.remaining..' respect points') or 'Not received')
            end
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
    im.SetCursorPos(im.ImVec2(22*S,516*S));im.TextDisabled(self.tab==6 and 'License statuses are received from the server.' or 'Health, armor and cash are live. Other fields use /stats. Carried items use /inv.')
    im.End()
    if not ok then error(err) end
end
return M

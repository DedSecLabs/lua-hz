local palette=require 'horizonbase.palette'
local M={}
function M.mod(ui)
    local self=ui;local im=ui.im
        im.TextWrapped('These commands control LuaHZ. Use /help in chat for Horizon server commands.')
        im.Spacing()
        local groups={
            {'Settings',{{'/luahz','Open settings (also '..self:keyName(self.prefs.keybinds.settingsPanel,self.prefs.modifiers.settingsPanel)..')'},
                {'/togs','Show which auto-accept options are enabled'},
                {'/luahzstatus','Open Character Status (also '..self:keyName(self.prefs.keybinds.characterStatus,self.prefs.modifiers.characterStatus)..')'},
                {'/luahzactions','Open character Quick Actions (also '..self:keyName(self.prefs.keybinds.quickActions,self.prefs.modifiers.quickActions)..')'},
                {'/luahzvehicle','Open the Vehicle menu (also '..self:keyName(self.prefs.keybinds.vehicleMenu,self.prefs.modifiers.vehicleMenu)..')'}}},
            {'Tracking',{{'/autofind [id/name]','Start periodic /find requests; use /autofind alone to stop. Horizon requires the detective job.'},
                {'/autotrackcar','Toggle periodic /trackcar requests for the vehicle you select.'}}},
            {'Auto-Accept',{{'/togrepair','Enable or disable accepting repair offers'},
                {'/togtaxi','Enable or disable accepting taxi calls'},
                {'/toglawyer','Enable or disable accepting defense offers'},
                {'/togwhore','Enable or disable accepting sex offers'},
                {'/togdrugs','Enable or disable accepting drug offers'}}},
            {'HUD',{{'/togstamina','Show or hide the stamina bar'},
                {'/togoxygen','Show or hide the oxygen bar'},
                {'/lvdb <0-2>','Dashboard style: 0 = Off, 1 = Full Dashboard, 2 = Minimal'}}},
            {'Troubleshooting',{{'/luahzdebug','Write the current HUD, map and component details to moonloader.log'},
                {'/luahzcapture families|rules|members|info|settings|myguns|help|carhelp','Send one requested read-only command and capture its response window'},
                {'/luahzcapture vehicles','Observe vehicle entry and commands you perform; never sends vehicle actions'},
                {'/luahzcapture on|off|status','Manual observation mode; stop capture or show its status'},
                {'/luahzversion','Show the server version observed during this connection'},
                {'/luahzreload','Save settings and reload LuaHZ'}}},
        }
        for _,group in ipairs(groups) do
            self:section(group[1])
            for _,row in ipairs(group[2]) do
                im.TextColored(palette.vec4(im,'accent'),row[1]);im.TextWrapped(row[2]);im.Spacing()
            end
            if group[1]=='Auto-Accept' then
                im.TextDisabled('Set offer price limits in Automation.');im.Spacing()
            end
        end
end
function M.draw(ui)
    local im=ui.im;local S=ui.scale;local origin=im.GetCursorScreenPos()
    local width=ui:availableWidth();local tabWidth=width/2;local dl=im.GetWindowDrawList()
    dl:AddLine(im.ImVec2(origin.x,origin.y+31*S),im.ImVec2(origin.x+width,origin.y+31*S),palette.u32(im,'border'),S)
    for i,label in ipairs({'Server commands','LuaHZ commands'})do
        local x=origin.x+(i-1)*tabWidth
        im.SetCursorScreenPos(im.ImVec2(x,origin.y))
        if im.InvisibleButton(label..'##commandTab'..i,im.ImVec2(tabWidth-4*S,30*S))then ui.commandPage=i;ui.infoNotice=nil end
        local selected=ui.commandPage==i
        local color=selected and palette.u32(im,'accent') or palette.u32(im,'muted')
        local size=im.CalcTextSize(label)
        dl:AddText(im.ImVec2(x+(tabWidth-size.x)/2,origin.y+(30*S-size.y)/2),color,label)
        if selected then dl:AddLine(im.ImVec2(x,origin.y+31*S),im.ImVec2(x+tabWidth-4*S,origin.y+31*S),color,3*S)end
    end
    im.SetCursorScreenPos(im.ImVec2(origin.x,origin.y+44*S))
    im.BeginChild('##commandsContent'..ui.commandPage,im.ImVec2(0,im.GetContentRegionAvail().y),false)
    local ok,err=pcall(function()
        if ui.commandPage==1 then require('horizonbase.information_ui').help(ui)else M.mod(ui)end
    end)
    im.EndChild();if not ok then error(err)end
end
return M

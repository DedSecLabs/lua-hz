local M={}
function M.normal(ui)
    local im=ui.im
    ui:section('Hotkeys','Hold modifiers, then a key; Del unsets.','keybinds')
    ui:bind('keybinds','settingsPanel','Settings Panel')
    ui:bind('keybinds','quickmap','Quickmap')
    ui:bind('keybinds','characterStatus','Character Status')
    ui:bind('keybinds','quickActions','Quick Actions')
    ui:bind('keybinds','siren','Toggle Siren')
    ui:bind('keybinds','reload','Reload animation')
    im.Spacing();ui:section('Cruise Control','Adjust speed with +/- when active','cruisecontrol')
    ui:bind('cruisecontrol','toggleKey','Toggle')
    for i=1,3 do ui:bind('cruisecontrol','preset'..i..'Key','Preset '..i..' (mph)','preset'..i..'Speed')end
    im.Spacing();ui:customCommands(false)
end
function M.draw(ui)
    local im=ui.im;local S=ui.scale;local origin=im.GetCursorScreenPos()
    local width=ui:availableWidth();local tabWidth=width/2;local dl=im.GetWindowDrawList()
    dl:AddLine(im.ImVec2(origin.x,origin.y+31*S),im.ImVec2(origin.x+width,origin.y+31*S),im.U32(.20,.21,.24,1),S)
    for i,label in ipairs({'Normal keybinds','Command combos'})do
        local x=origin.x+(i-1)*tabWidth
        im.SetCursorScreenPos(im.ImVec2(x,origin.y))
        if im.InvisibleButton(label..'##keybindTab'..i,im.ImVec2(tabWidth-4*S,30*S))then
            if ui.keybindPage~=i then ui:clearDraft();ui.capture=nil end
            ui.keybindPage=i
        end
        local selected=ui.keybindPage==i
        local color=selected and im.U32(1,.62,0,1) or im.U32(.64,.66,.70,1)
        local size=im.CalcTextSize(label)
        dl:AddText(im.ImVec2(x+(tabWidth-size.x)/2,origin.y+(30*S-size.y)/2),color,label)
        if selected then dl:AddLine(im.ImVec2(x,origin.y+31*S),im.ImVec2(x+tabWidth-4*S,origin.y+31*S),color,3*S)end
    end
    im.SetCursorScreenPos(im.ImVec2(origin.x,origin.y+44*S))
    im.BeginChild('##keybindsContent'..ui.keybindPage,im.ImVec2(0,im.GetContentRegionAvail().y),false)
    local ok,err=pcall(function()
        if ui.keybindPage==1 then M.normal(ui)else ui:customCommands(true)end
    end)
    im.EndChild();if not ok then error(err)end
end
return M

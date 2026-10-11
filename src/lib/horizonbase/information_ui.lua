local ffi=require 'ffi'
local M={}
local kinds={'families','members','rules','settings','info'}
local function status(im,page)
    if page.loading then im.TextDisabled('Requesting server response...')end
    if page.updatedAt then im.TextDisabled(('Snapshot updated %d seconds ago.'):format(math.max(0,math.floor((getGameTimer()-page.updatedAt)/1000))))end
    if page.partial then im.TextWrapped('Some response data was not recognized or was missing. Refresh to try again.')end
    if page.error then im.TextWrapped(page.error)end
    if not page.updatedAt and not page.loading then im.TextWrapped('Click Refresh to request this information from Horizon.')end
end
local function columns(im,id,widths,draw)
    im.Columns(#widths,id,false)
    for i,width in ipairs(widths)do im.SetColumnWidth(i-1,width)end
    local ok,err=pcall(draw)
    im.Columns(1)
    if not ok then error(err)end
end
local function cell(im,text)im.TextWrapped(tostring(text));im.NextColumn()end
function M.help(ui)
    local im=ui.im;local server=ui.server
    local page=server and server.info and server.info.pages.help
    if not page then im.TextWrapped('Server commands are unavailable.');return end
    if im.Button('Refresh##horizon-help')then
        if server:requestInfo('help')then ui.infoNotice=nil
        else ui.infoNotice='Another request is running, Refresh is on cooldown, or gameplay is unavailable.'end
    end
    if ui.infoNotice then im.TextWrapped(ui.infoNotice)end
    status(im,page);im.Spacing()
    im.TextWrapped('Commands available to your character, supplied by Horizon. This list is for reference.')
    im.TextDisabled('Search commands or categories')
    im.PushItemWidth(ui:availableWidth());im.InputText('##search-help',ui.helpSearch,65);im.PopItemWidth()
    local query=ffi.string(ui.helpSearch):lower()
    for _,row in ipairs(page.rows)do
        if (row.category..' '..row.text):lower():find(query,1,true) then
            ui:title(row.category);im.TextWrapped(row.text);im.Spacing()
        end
    end
end
function M.compatibility(ui)
    local im=ui.im;local o=ui.observations
    im.TextUnformatted('Observed version: '..(o and not o.versionConflict and o.observedVersion or 'Unknown'))
    im.TextDisabled('Reference version: 2.4.47 [Z]')
    im.TextWrapped(o and o:versionStatus() or 'Version not observed; compatibility not verified.')
    im.TextWrapped('Version observations do not disable features. After a script reload, reconnect to observe the login banner again.')
    im.Spacing();ui:section('Response diagnostics')
    im.TextWrapped('/luahzcapture families, rules, members, info, settings, myguns or help requests one read-only command and records an eight-second response window.')
    if o and ui.captureAction then
        im.TextUnformatted(o.active and 'Capture enabled' or 'Capture off')
        if o.active then
            if im.Button('Stop capture')then ui.captureAction('off')end
        else
            if im.Button('Start capture')then ui.captureAction('on')end
            if im.Button('Capture /families')then ui.captureAction('families');ui.open[0]=false end
        end
        if o.path then im.TextWrapped('Local file: '..o.path)end
        if o.captureError then im.TextWrapped(o.captureError)end
        if o.lastReason then im.TextDisabled('Last capture: '..o.lastReason)end
    end
    im.TextWrapped('Manual capture observes commands you use. /buylevel can purchase a level and is never requested automatically.')
    im.TextWrapped('/myguns currently returns a time and an unidentified number; no gun locations have been established.')
end
function M.draw(ui)
    local im=ui.im
    local tabLabels={'Families','Members','Rules','Settings','Links','Status'}
    local origin=im.GetCursorScreenPos();local width=ui:availableWidth();local tabWidth=width/#tabLabels;local S=ui.scale
    local dl=im.GetWindowDrawList()
    dl:AddLine(im.ImVec2(origin.x,origin.y+31*S),im.ImVec2(origin.x+width,origin.y+31*S),im.U32(.20,.21,.24,1),S)
    for i,label in ipairs(tabLabels)do
        local x=origin.x+(i-1)*tabWidth
        im.SetCursorScreenPos(im.ImVec2(x,origin.y))
        if im.InvisibleButton(label..'##serverTab'..i,im.ImVec2(tabWidth-4*S,30*S))then ui.horizonPage[0]=i-1;ui.infoNotice=nil end
        local selected=ui.horizonPage[0]==i-1
        local color=selected and im.U32(1,.62,0,1) or im.IsItemHovered() and im.U32(1,1,1,1) or im.U32(.64,.66,.70,1)
        local size=im.CalcTextSize(label)
        dl:AddText(im.ImVec2(x+(tabWidth-size.x)/2,origin.y+(30*S-size.y)/2),color,label)
        if selected then dl:AddLine(im.ImVec2(x,origin.y+31*S),im.ImVec2(x+tabWidth-4*S,origin.y+31*S),color,3*S)end
    end
    im.SetCursorScreenPos(im.ImVec2(origin.x,origin.y+44*S))
    local index=ui.horizonPage[0]+1
    im.BeginChild('##serverContent'..index,im.ImVec2(0,im.GetContentRegionAvail().y),false)
    local ok,err=pcall(M.content,ui,index)
    im.EndChild()
    if not ok then error(err)end
end
function M.content(ui,index)
    local im=ui.im
    if index==6 then M.compatibility(ui);return end
    local kind=kinds[index];if not kind then return end
    local server=ui.server;local page=server and server.info and server.info.pages[kind]
    if not page then im.TextWrapped('Server information is unavailable.');return end
    if im.Button('Refresh##horizon-'..kind)then
        if server:requestInfo(kind)then ui.infoNotice=nil
        else ui.infoNotice='Another request is running, Refresh is on cooldown, or gameplay is unavailable.' end
    end
    if ui.infoNotice then im.TextWrapped(ui.infoNotice)end
    status(im,page);im.Spacing()
    if kind=='families' or kind=='members' then
        local buffer=ui.horizonSearch[kind]
        im.TextDisabled(kind=='families' and 'Search families or leaders' or 'Search names, titles or ranks')
        im.PushItemWidth(ui:availableWidth());im.InputText('##search-'..kind,buffer,65);im.PopItemWidth()
        local query=ffi.string(buffer):lower();local rows={}
        for _,row in ipairs(page.rows)do
            local text=row.name..' '..(row.leader or row.title or '')..' '..(row.label or '')
            if query=='' or text:lower():find(query,1,true)then rows[#rows+1]=row end
        end
        im.TextDisabled(#rows..' shown / '..#page.rows..' received');im.Spacing()
        local width=ui:availableWidth()
        if kind=='families' then
            columns(im,'##familyColumns',{width*.40,width*.34,width*.13,width*.13},function()
                for _,label in ipairs({'Family','Leader','Total','Online'})do cell(im,label)end
                im.Separator()
                for _,row in ipairs(rows)do
                    cell(im,row.id..'. '..row.name);cell(im,row.leader);cell(im,row.members);cell(im,row.online)
                end
            end)
        else
            columns(im,'##memberColumns',{width*.49,width*.17,width*.34},function()
                for _,label in ipairs({'Member','Rank','Rank name'})do cell(im,label)end
                im.Separator()
                for _,row in ipairs(rows)do
                    im.TextWrapped(row.name)
                    im.PushStyleColor(im.Col.Text,im.ImVec4(.55,.57,.60,1));im.TextWrapped(row.title);im.PopStyleColor()
                    im.NextColumn();cell(im,row.rank);cell(im,row.label)
                end
            end)
        end
    elseif kind=='rules' then
        im.TextWrapped('This is the short rule summary supplied by Horizon.')
        for _,row in ipairs(page.rows)do ui:title(row.title);im.TextWrapped(row.text);im.Spacing()end
        if im.Button('Copy full-rulebook website')then im.SetClipboardText('https://hzgaming.net')end
        im.TextDisabled('Server reference: hzgaming.net')
    elseif kind=='settings' then
        im.TextWrapped('Horizon server settings. LuaHZ preferences are separate.')
        local names=require('horizonbase.server_info').settingNames
        for _,name in ipairs(names)do
            im.TextUnformatted(name);im.SameLine()
            local value=page.fields[name]
            im.TextColored(value=='On' and im.ImVec4(.25,.8,.4,1) or value=='Off' and im.ImVec4(.85,.35,.3,1) or im.ImVec4(.5,.5,.5,1),value or 'Not received')
        end
        if page.commands then im.Spacing();ui:section('Server commands');im.TextWrapped(page.commands)end
    elseif kind=='info' then
        for _,name in ipairs(require('horizonbase.server_info').linkNames)do
            ui:title(name)
            local url=page.fields[name];im.TextWrapped(url or 'Not received')
            if url and im.SmallButton('Copy URL##'..name)then im.SetClipboardText(url)end
            im.Spacing()
        end
    end
end
return M

local config = require 'horizonbase.config'
local logic = require 'horizonbase.logic'
local keys = require 'horizonbase.keys'
local M = {}; M.__index = M
local tabs = {'HUD', 'Quickmap', 'Automation', 'Keybinds', 'Performance', 'Commands', 'Settings', 'Changelog', 'Server'}
local tabIcons={'monitor','map','bot','keyboard','gauge','terminal','settings','scroll-text','server'}

function M.new(imgui, prefs, save, notify)
    local self = setmetatable({im=imgui, prefs=prefs, save=save, notify=notify,
        open=imgui.new.bool(false), tab=1, controls={}, capture=nil, scale=1, scaleDragging=false, previewMap=false}, M)
    self.commandPage=1;self.keybindPage=1;self.helpSearch=imgui.new.char[65]('')
    self.horizonPage=imgui.new.int(0)
    self.horizonSearch={families=imgui.new.char[65](''),members=imgui.new.char[65]('')}
    self:refreshControls()
    self:clearDraft()
    return self
end

function M:clearDraft()
    self.draft={name=self.im.new.char[65](''),command=self.im.new.char[145](''),command2=self.im.new.char[145](''),key=0,mods=0}
    self.editIndex=nil;self.bindError=nil
end

function M:customCommands(combos)
    local im=self.im;local S=self.scale
    if combos then im.TextWrapped('One shortcut for a two-command sequence or vehicle-lock fallback.')
    else self:section('Custom commands','One shortcut runs one command.')end
    for i,binding in ipairs(self.prefs.custombinds) do
        if (binding.command2~=nil)==(combos==true) then
            im.TextUnformatted(binding.name);im.TextDisabled(binding.command)
            if binding.command2 then
                local smart=require('horizonbase.vehicle_locks').pair(binding.command,binding.command2)
                im.TextDisabled((smart and 'Fallback: ' or 'Then ')..binding.command2)
            end
            local active=self.capture and self.capture.custom==i
            if im.Button((active and '[ Press combo ]' or self:keyName(binding.key,binding.mods))..'##customkey'..i,im.ImVec2(210*S,28*S)) then
                self.capture={custom=i}
            end
            im.SameLine()
            if im.Button('Edit##custom'..i,im.ImVec2(72*S,28*S)) then
                self:clearDraft();self.editIndex=i
                im.StrCopy(self.draft.name,binding.name);im.StrCopy(self.draft.command,binding.command)
                im.StrCopy(self.draft.command2,binding.command2 or '')
                self.draft.key=binding.key;self.draft.mods=binding.mods or 0;self.capture=nil
            end
            im.SameLine()
            if im.Button('Remove##custom'..i,im.ImVec2(72*S,28*S)) then
                table.remove(self.prefs.custombinds,i);self:clearDraft();self.capture=nil;self.save();break
            end
            im.Spacing()
        end
    end
    im.Separator()
    self:title(self.editIndex and (combos and 'Edit combo' or 'Edit keybind') or (combos and 'New combo' or 'New keybind'))
    if combos and not self.editIndex and im.SmallButton('Vehicle locks preset')then
        self:clearDraft();im.StrCopy(self.draft.name,'Vehicle locks')
        im.StrCopy(self.draft.command,'/pvl');im.StrCopy(self.draft.command2,'/gvl')
    end
    im.PushItemWidth(self:availableWidth())
    im.TextDisabled(combos and 'Name (example: Vehicle locks)' or 'Name (example: Player stats)')
    im.InputText('##customname',self.draft.name,65)
    im.TextDisabled(combos and 'First command' or 'Game command (example: /stats)')
    im.InputText('##customcommand',self.draft.command,145)
    if combos then
        im.TextDisabled('Second command')
        im.InputText('##customcommand2',self.draft.command2,145)
    end
    im.PopItemWidth()
    local active=self.capture and self.capture.draft
    if im.Button((active and '[ Press combo ]' or self:keyName(self.draft.key,self.draft.mods))..'##draftkey',im.ImVec2(210*S,28*S)) then
        self.capture={draft=true}
    end
    im.SameLine()
    if im.Button('Save keybind') then
        local ffi=require 'ffi'
        local binding=config.binding({name=ffi.string(self.draft.name),command=ffi.string(self.draft.command),command2=combos and ffi.string(self.draft.command2) or nil,key=self.draft.key,mods=self.draft.mods},#self.prefs.custombinds+1)
        local conflict=config.keyConflict(self.prefs,self.draft.key,self.editIndex,self.draft.mods)
        if not binding or combos and not binding.command2 then self.bindError=combos and 'Enter two commands beginning with / (maximum 144 characters each).' or 'Enter a command beginning with / (maximum 144 characters).'
        elseif self.draft.key==0 then self.bindError='Assign a key before adding the keybind.'
        elseif conflict then self.bindError='This key is already assigned to '..conflict..'.'
        elseif not self.editIndex and #self.prefs.custombinds>=20 then self.bindError='You can save up to 20 custom keybinds.'
        else
            self.prefs.custombinds[self.editIndex or #self.prefs.custombinds+1]=binding
            self.save();self.capture=nil;self:clearDraft()
        end
    end
    if self.editIndex then im.SameLine();if im.SmallButton('Cancel edit') then self.capture=nil;self:clearDraft() end end
    if self.bindError then im.TextWrapped(self.bindError) end
    im.TextDisabled('Hold Ctrl, Alt, Shift or Win, then press a key.')
    if combos then
        im.TextWrapped('Typing, menus or leaving gameplay cancel the second command.')
        im.TextWrapped('Vehicle locks stops after success and tries the other vehicle type only after a not-nearby reply. No confirmed reply means no fallback.')
    else im.TextDisabled('Commands run once per press while playing.')end
end

function M:keyName(code,mods)
    if code == 0 then return 'Click to set keybind' end
    local parts={};local bit=require 'bit'
    for _,item in ipairs({{1,'Ctrl'},{2,'Shift'},{4,'Alt'},{8,'Win'}}) do
        if bit.band(mods or 0,item[1])~=0 then parts[#parts+1]=item[2] end
    end
    local name=require('vkeys').id_to_name(code) or ('Key '..code)
    parts[#parts+1]=name:gsub('^VK_','')
    return table.concat(parts,' + ')
end

function M:availableWidth()
    return self.contentWidth or self.im.GetContentRegionAvail().x
end

function M:refreshControls()
    local im = self.im
    self.controls = {}
    for section, fields in pairs(self.prefs) do
        self.controls[section]={}
        for key,value in pairs(fields) do
            if type(value)=='boolean' then self.controls[section][key]=im.new.bool(value)
            elseif type(value)=='number' then self.controls[section][key]=im.new.int(value) end
        end
    end
    self.fpsText={}
    for key,n in pairs(self.prefs.fps) do self.fpsText[key]=im.new.char[16](n==0 and 'MAX' or tostring(n)) end
end

function M:changed(section, key, value)
    self.prefs[section][key]=value
    self.save()
end

function M:theme()
    local im=self.im
    local width,height=getScreenResolution()
    self.scale=logic.interfaceScale(width,height,self.prefs.interface.scale,logic.menuWidth)
    local S=self.scale
    im.GetIO().FontGlobalScale=S*15/(im.FontBaseSize or 15)
    local style=im.GetStyle()
    style.WindowRounding=15*S; style.ChildRounding=10*S; style.FrameRounding=7*S
    style.GrabRounding=7*S; style.WindowBorderSize=0; style.FrameBorderSize=0
    style.ScrollbarSize=6*S; style.ScrollbarRounding=6*S
    style.WindowPadding=im.ImVec2(0,0); style.ItemSpacing=im.ImVec2(10*S,9*S)
    style.FramePadding=im.ImVec2(10*S,6*S)
    local colors={WindowBg={.125,.135,.15,1},ChildBg={0,0,0,0},Text={.84,.85,.87,1},
        TextDisabled={.46,.48,.53,1},FrameBg={.105,.115,.13,1},FrameBgHovered={.15,.16,.18,1},
        FrameBgActive={.17,.18,.20,1},Button={.18,.19,.21,1},ButtonHovered={.24,.23,.20,1},
        ButtonActive={.36,.26,.10,1},Header={.32,.24,.10,1},HeaderHovered={.38,.28,.09,1},
        HeaderActive={.48,.33,.09,1},CheckMark={1,.62,0,1},SliderGrab={1,.62,0,1},
        SliderGrabActive={1,.72,.10,1},Separator={.20,.21,.23,1},PopupBg={.13,.14,.16,1},
        ScrollbarBg={0,0,0,0},ScrollbarGrab={.21,.23,.27,1}}
    for name,value in pairs(colors) do style.Colors[im.Col[name]]=im.ImVec4(unpack(value)) end
end

function M:title(text,color)
    local im=self.im
    im.SetWindowFontScale(1.2)
    if color then im.TextColored(color,text) else im.TextUnformatted(text) end
    im.SetWindowFontScale(1)
end

function M:section(title, hint, resetSection)
    local im=self.im
    self:title(title)
    if resetSection then
        im.SameLine()
        if im.SmallButton('Reset##'..resetSection) then
            self.prefs[resetSection]=config.copy(config.defaults[resetSection])
            if resetSection=='keybinds' or resetSection=='cruisecontrol' then
                for key in pairs(config.defaults[resetSection]) do if self.prefs.modifiers[key]~=nil then self.prefs.modifiers[key]=0 end end
                for i,binding in ipairs(self.prefs.custombinds) do
                    if config.keyConflict(self.prefs,binding.key,i,binding.mods) then binding.key=0 end
                end
            end
            self.capture=nil;self:refreshControls();self.save()
        end
    end
    im.Separator()
    if hint then im.TextDisabled(hint) end
    im.Spacing()
end

function M:toggle(section,key,label,hint,amountKey)
    local im=self.im;local S=self.scale
    local origin=im.GetCursorScreenPos()
    local right=origin.x+self:availableWidth()
    im.TextUnformatted(label)
    if hint then im.TextDisabled(hint) end
    if amountKey then
        im.SetCursorScreenPos(im.ImVec2(right-127*S,origin.y-3*S)); im.PushItemWidth(79*S)
        if im.InputInt('##amount'..key,self.controls[section][amountKey],0,0) then
            self.controls[section][amountKey][0]=math.max(0,math.min(1000000,self.controls[section][amountKey][0]))
            self:changed(section,amountKey,self.controls[section][amountKey][0])
        end
        im.PopItemWidth()
    end
    im.SetCursorScreenPos(im.ImVec2(right-34*S,origin.y+1*S))
    local enabled=self.prefs[section][key]
    if im.InvisibleButton('##toggle'..section..key,im.ImVec2(34*S,20*S)) then
        enabled=not enabled; self.controls[section][key][0]=enabled;self:changed(section,key,enabled)
    end
    local dl=im.GetWindowDrawList()
    dl:AddRectFilled(im.ImVec2(right-34*S,origin.y+2*S),im.ImVec2(right,origin.y+20*S),
        im.U32(enabled and 1 or .24,enabled and .61 or .25,enabled and 0 or .28,1),10*S)
    dl:AddCircleFilled(im.ImVec2(right-(enabled and 9 or 25)*S,origin.y+11*S),6*S,im.U32(.97,.97,.98,1),16)
    im.SetCursorScreenPos(im.ImVec2(origin.x,origin.y+(hint and 54 or 38)*S))
end

function M:bind(section,key,label,speedKey)
    local im=self.im;local S=self.scale
    local pos=im.GetCursorScreenPos();local right=pos.x+self:availableWidth()
    im.AlignTextToFramePadding();im.TextUnformatted(label)
    if speedKey then
        im.SetCursorScreenPos(im.ImVec2(right-303*S,pos.y));im.PushItemWidth(83*S)
        if im.InputInt('##speed'..key,self.controls[section][speedKey],0,0) then
            self.controls[section][speedKey][0]=math.max(1,math.min(200,self.controls[section][speedKey][0]))
            self:changed(section,speedKey,self.controls[section][speedKey][0])
        end
        im.PopItemWidth()
    end
    im.SetCursorScreenPos(im.ImVec2(right-210*S,pos.y))
    local active=self.capture and self.capture.section==section and self.capture.key==key
    if im.Button((active and '[ Press combo ]' or self:keyName(self.prefs[section][key],self.prefs.modifiers[key]))..'##'..key,im.ImVec2(210*S,28*S)) then
        self.capture={section=section,key=key};self.ignoreKeysUntil=0
    end
    im.SetCursorScreenPos(im.ImVec2(pos.x,pos.y+39*S))
end

function M:captureKey(code, now, mods)
    if not self.capture then return false end
    if keys.isModifier(code) then return true end -- Keep waiting for the main key.
    mods=mods or keys.modifiers()
    if code~=27 or mods~=0 then
        local value=(mods==0 and (code==46 or code==8)) and 0 or code
        if value==0 then mods=0 end
        local c=self.capture
        if c.draft then
            self.draft.key=value;self.draft.mods=mods;self.bindError=nil
        else
            local conflict=config.keyConflict(self.prefs,value,c.custom,mods,c.section,c.key)
            if conflict then self.bindError='This combination is already assigned to '..conflict..'.'
            elseif c.custom then
                local binding=self.prefs.custombinds[c.custom]
                binding.key=value;binding.mods=mods;self.save();self.bindError=nil
            else
                self.prefs.modifiers[c.key]=mods
                self:changed(c.section,c.key,value);self.bindError=nil
            end
        end
    end
    self.capture=nil;self.ignoreKeysUntil=now+300
    return true
end

function M:isMapPreview()
    return self.open[0] and self.tab==2 and self.previewMap
end

function M:slider(section,key,label,minimum,maximum,format)
    local im=self.im
    im.TextUnformatted(label);im.PushItemWidth(self:availableWidth())
    if im.SliderInt('##'..section..key,self.controls[section][key],minimum,maximum,format) then
        self:changed(section,key,self.controls[section][key][0])
    end
    if section=='interface' and key=='scale' then self.scaleDragging=im.IsItemActive() end
    im.PopItemWidth();im.Spacing()
end

function M:content()
    local im=self.im;local S=self.scale
    if self.tab==1 then
        self:section('Display')
        self:toggle('settings','stamina','Stamina Bar','Display stamina when running')
        self:toggle('settings','oxygen','Oxygen Bar','Display oxygen when underwater')
        im.Spacing();self:section('Vehicle')
        im.TextUnformatted('Dashboard Style');im.TextDisabled('Vehicle speedometer and health display')
        im.PushItemWidth(self:availableWidth())
        local options={'Off','Full Dashboard','Minimal'}
        -- Popup padding keeps the first/last row's hit area and highlight unclipped.
        im.PushStyleVarVec2(im.StyleVar.WindowPadding,im.ImVec2(10*S,10*S))
        local rowHeight=im.GetFontSize()+6*S
        local popupHeight=20*S+#options*rowHeight+(#options-1)*im.GetStyle().ItemSpacing.y+2*S
        im.SetNextWindowSizeConstraints(im.ImVec2(0,popupHeight),im.ImVec2(100000,popupHeight))
        if im.BeginCombo('##dashboard',options[self.prefs.settings.vdb+1]) then
            for i,label in ipairs(options) do
                local selected=self.prefs.settings.vdb==i-1
                if im.Selectable(label..'##dashboardOption'..i,selected,0,im.ImVec2(0,rowHeight)) then
                    self.controls.settings.vdb[0]=i-1
                    self:changed('settings','vdb',i-1)
                end
                if selected then im.SetItemDefaultFocus() end
            end
            im.EndCombo()
        end
        im.PopStyleVar()
        im.PopItemWidth()
    elseif self.tab==2 then
        self:section('Quickmap','Customize the fullscreen map overlay')
        im.TextUnformatted('Map Opacity');im.PushItemWidth(self:availableWidth())
        if im.SliderInt('##opacity',self.controls.quickmap.opacity,0,100,'%d%%') then
            self:changed('quickmap','opacity',self.controls.quickmap.opacity[0])
            self.previewMap=true
        end
        im.PopItemWidth()
        if im.Button(self.previewMap and 'Hide preview' or 'Preview map') then self.previewMap=not self.previewMap end
        im.TextDisabled('Opacity changes preview behind this window.')
        im.Spacing();self:section('Elements')
        self:toggle('quickmap','gangzones','Gang Zones','Show territory zones on the map')
        self:toggle('quickmap','rememberLocations','Remember Locations','Build your Horizon map automatically as you play')
        self:toggle('quickmap','nativeLocations','Native Map Locations','Show remembered places on the ESC map')
        local catalog=self.overlay and self.overlay.server.catalog
        if catalog and catalog.address then
            im.TextDisabled(('Saved locations: %d'):format(#catalog.records))
            if im.Button('Clear saved locations',im.ImVec2(0,28*self.scale)) then
                local cleared,err=catalog:clear()
                self.notify(cleared and 'Saved Horizon locations cleared.' or tostring(err))
            end
        end
    elseif self.tab==3 then
        self:section('Auto-Accept','Auto-accept offers up to max $')
        self:toggle('togs','repair','Repair',nil,'repairMax')
        self:toggle('togs','lawyer','Defense',nil,'lawyerMax')
        self:toggle('togs','whore','Sex',nil,'whoreMax')
        self:toggle('togs','drugs','Drugs',nil,'drugsMax')
        self:toggle('togs','taxi','Taxi Calls')
        im.Spacing();self:section('Detective')
        self:toggle('autofind','cohort','Autofind Cohort','Also check who target was last seen with')
    elseif self.tab==4 then
        require('horizonbase.keybinds_ui').draw(self)
    elseif self.tab==5 then
        self:section('FPS Limiter','Limit FPS per situation, or leave as MAX for no extra cap','fps')
        for _,row in ipairs({{'onfoot','On Foot'},{'invehicle','Driving'},{'swimming','Swimming'},{'inboat','In Boat'}}) do
            local pos=im.GetCursorScreenPos();local right=pos.x+self:availableWidth()
            im.AlignTextToFramePadding();im.TextUnformatted(row[2]);im.SetCursorScreenPos(im.ImVec2(right-110*S,pos.y));im.PushItemWidth(110*S)
            local changed=im.InputText('##fps'..row[1],self.fpsText[row[1]],16,im.InputTextFlags.EnterReturnsTrue)
            if changed or im.IsItemDeactivatedAfterEdit() then
                local raw=require('ffi').string(self.fpsText[row[1]])
                local n=tonumber(raw) or 0
                n=n==0 and 0 or math.floor(math.max(20,math.min(300,n)))
                self:changed('fps',row[1],n)
                im.StrCopy(self.fpsText[row[1]],n==0 and 'MAX' or tostring(n))
            end
            im.PopItemWidth();im.SetCursorScreenPos(im.ImVec2(pos.x,pos.y+40*S))
        end
    elseif self.tab==6 then
        require('horizonbase.commands_ui').draw(self)
    elseif self.tab==7 then
        self:section('Interface','Automatic display scaling plus your preferred size','interface')
        self:slider('interface','scale','UI size',80,200,'%d%%')
        im.TextDisabled('Release the slider to apply. The panel fits your screen.')
        im.Spacing();self:section('HUD layout','One size for player and dashboard HUDs.','hud')
        self:slider('hud','scale','HUD size',50,200,'%d%%')
        self:slider('hud','x','Horizontal position',0,100,'%d%%')
        self:slider('hud','y','Vertical position',0,100,'%d%%')
        im.TextDisabled('0% = left/top. 100% = right/bottom.')
    elseif self.tab==8 then
        self:section('Changelog')
        im.TextUnformatted('LuaHZ 0.4.0-rc.5 — local test')
        im.BulletText('Neutral icons replace Unknown and waiting captions')
        im.BulletText('Trunk contents requested in K stay silent; manual commands print normally')
        im.BulletText('Compact right-side K Vehicle menu; move normally and hold Alt to click')
        im.BulletText('Dashboard status: doors, engine, lights and window')
        im.BulletText('Nearby trunk controls and session-only contents viewer')
        im.BulletText('Character licenses and Quick Actions matched to current jobs')
        im.BulletText('Unsupported vehicle replies end waiting immediately')
        im.BulletText('Dedicated K Vehicle menu: controls, storage and tracking')
        im.BulletText('Personal/Family dashboard badges use confirmed entry messages')
        im.BulletText('U Quick Actions now focuses on character actions')
        im.Spacing()
        im.TextUnformatted('LuaHZ 0.3.2 — local test')
        im.BulletText('Lock icons share the dashboard background; state labels are easier to read')
        im.Spacing()
        im.TextUnformatted('LuaHZ 0.3.1 — local test')
        im.BulletText('Larger, brighter vehicle icons with explicit Locked/Unlocked labels')
        im.BulletText('Manual vehicle capture observes entry, controls, storage and tracking menus')
        im.Spacing()
        im.TextUnformatted('LuaHZ 0.3.0')
        im.BulletText('Quick Actions, Server pages, smart locks and unified HUD notices')
        im.BulletText('Backed-up upgrades preserve preferences and saved locations')
        im.Spacing()
        im.TextUnformatted('LuaHZ 0.2.54')
        im.BulletText('Quick Actions status rows and player-selector controls share consistent margins')
        im.BulletText('Find, Back and Refresh have equal heights; Refresh uses a secondary style')
        im.Spacing()
        im.TextUnformatted('LuaHZ 0.2.53')
        im.BulletText('Quick Actions opens with U: clear navigation, smart locks, vehicle tracking and find player')
        im.BulletText('Confirmed navigation clearing stops local tracking and queued requests without removing saved places')
        im.Spacing()
        im.TextUnformatted('LuaHZ 0.2.52')
        im.BulletText('Stamina and oxygen panels are 15% wider and have right-aligned labels')
        im.BulletText('Notifications match their width, height and right edge at every HUD size')
        im.Spacing()
        im.TextUnformatted('LuaHZ 0.2.51')
        im.BulletText('All notifications share a larger card, text and icon style')
        im.BulletText('Notifications sit above visible stamina, oxygen and vehicle panels')
        im.Spacing()
        im.TextUnformatted('LuaHZ 0.2.50')
        im.BulletText('Vehicle locks shows one notice when neither vehicle type is nearby')
        im.BulletText('Repeated lock notices refresh instead of stacking in chat')
        im.Spacing()
        im.TextUnformatted('LuaHZ 0.2.49')
        im.BulletText('Vehicle locks stops on success and tries the other scope only after a not-nearby reply')
        im.BulletText('Keybinds separates normal shortcuts from two-command combos')
        im.Spacing()
        im.TextUnformatted('LuaHZ 0.2.48')
        im.BulletText('Vehicle locks preset sends personal and group lock commands from one shortcut')
        im.BulletText('Custom keybinds can run two commands, with a two-second gap and gameplay cancellation')
        im.BulletText('Commands has separate server help and LuaHZ references; server help supports search and Refresh')
        im.Spacing()
        im.TextUnformatted('LuaHZ 0.2.47')
        im.BulletText('Members Refresh stays quiet when the outgoing command callback is delayed')
        im.BulletText('Server Refresh buttons no longer show technical source-command labels')
        im.Spacing()
        im.TextUnformatted('LuaHZ 0.2.46')
        im.BulletText('Both menus share a wider layout; the Family column has more space')
        im.BulletText('Server tab content omits repeated section headings')
        im.Spacing()
        im.TextUnformatted('LuaHZ 0.2.45')
        im.BulletText('Server Refresh quietly collects its own recognized response rows')
        im.BulletText('Server section uses Lucide server icon and underlined information tabs')
        im.BulletText('F9 matches Character Status width; successful refresh clears its notice')
        im.Spacing()
        im.TextUnformatted('LuaHZ 0.2.44')
        im.BulletText('Horizon pages show searchable families and members, rules, server settings and community links')
        im.BulletText('Manual /buylevel replies can show remaining respect in Character Status')
        im.Spacing()
        im.TextUnformatted('LuaHZ 0.2.43')
        im.BulletText('Direct read-only command capture arms recording before the command is sent')
        im.BulletText('Capture files record their stop reason and direct captures stop automatically')
        im.Spacing()
        im.TextUnformatted('LuaHZ 0.2.42')
        im.BulletText('Server version observation uses received events without scanning native textdraw strings')
        im.Spacing()
        im.TextUnformatted('LuaHZ 0.2.41')
        im.BulletText('Horizon page shows the observed server version and compatibility status')
        im.BulletText('Optional local capture helps investigate complete server command responses')
        im.Spacing()
        im.TextUnformatted('LuaHZ 0.2.40')
        im.BulletText('Oxygen bar shows in submerged vehicles, above the vehicle dashboard')
        im.Spacing();im.TextUnformatted('LuaHZ 0.2.39')
        im.BulletText('A cut-off Job 2 is filled from the job commands in /help')
        im.Spacing();im.TextUnformatted('LuaHZ 0.2.38')
        im.BulletText('Oxygen bar hides on foot so the stamina bar can show while running')
        im.Spacing();im.TextUnformatted('LuaHZ 0.2.37')
        im.BulletText('Automatic /inv no longer prints the Inventory header in chat')
        im.Spacing();im.TextUnformatted('LuaHZ 0.2.36')
        im.BulletText('Character Status keeps finished /stats fields when chat cuts off the line')
        im.BulletText('Family and Crew fill Faction and Division')
        im.BulletText('Inventory adds carried items from /inv')
        im.Spacing();im.TextUnformatted('LuaHZ 0.2.35')
        im.BulletText('User-supplied GTA-style loading artwork; source image preserved unchanged')
        im.Spacing();im.TextUnformatted('LuaHZ 0.2.34')
        im.BulletText('New upper-left gang scene; project source/handoff cleanup')
        im.Spacing();im.TextUnformatted('LuaHZ 0.2.33')
        im.BulletText('HZ-only startup loading artwork and footer bar; original binaries restored')
        im.Spacing();im.TextUnformatted('LuaHZ 0.2.32')
        im.BulletText('HZ-only native fonts, radar icons and map textures with original-file fallback')
        im.Spacing();im.TextUnformatted('LuaHZ 0.2.31')
        im.BulletText('Load notification moved to the bottom right')
        im.Spacing();im.TextUnformatted('LuaHZ 0.2.30')
        im.BulletText('Features load only on the verified HZ endpoint and release on leaving')
        im.Spacing();im.TextUnformatted('LuaHZ 0.2.29')
        im.BulletText('Sharper loading texture and live bar aligned with the footer credits')
        im.Spacing();im.TextUnformatted('LuaHZ 0.2.28')
        im.BulletText('Centered live loading bar; Campbell scene replaces the upper-right police tile')
        im.Spacing();im.TextUnformatted('LuaHZ 0.2.27')
        im.BulletText('Full-screen Horizon loading artwork with correct widescreen proportions')
        im.Spacing();im.TextUnformatted('LuaHZ 0.2.26')
        im.BulletText('Correct SAMPFUNCS loading artwork; smoother resource startup')
        im.Spacing();im.TextUnformatted('LuaHZ 0.2.25')
        im.BulletText('Character fields use the tab label without a repeated heading')
        im.Spacing();im.TextUnformatted('LuaHZ 0.2.24')
        im.BulletText('Underlined character tabs; Refresh below player details')
        im.BulletText('More space between sidebar branding and navigation')
        im.Spacing();im.TextUnformatted('LuaHZ 0.2.23')
        im.BulletText('Weapon switching pauses until the reload animation finishes')
        im.BulletText('Five Character Status tabs and larger HZ moon logo')
        im.Spacing();im.TextUnformatted('LuaHZ 0.2.22')
        im.BulletText('Current-skin avatar and live health, armor and cash in Character Status')
        im.BulletText('Remembered locations on the native ESC map')
        im.Spacing();im.TextUnformatted('LuaHZ 0.2.21')
        im.BulletText('Run/swim icons with compact energy bars and no text')
        im.BulletText('Vehicle health percent and stable MPH without leading zeros')
        im.BulletText('HD Quickmap icons available on native radar and ESC map')
        im.Spacing();im.TextUnformatted('LuaHZ 0.2.20')
        im.BulletText('Sharper dashboard text, larger supplied icons and native bars')
        im.BulletText('HUD waits for successful login; HD native game fonts')
        im.Spacing();im.TextUnformatted('LuaHZ 0.2.19')
        im.BulletText('Bottom-right dashboard with segmented gauges and lock icons')
        im.BulletText('Reload hotkey restricted to firearms')
        im.Spacing();im.TextUnformatted('LuaHZ 0.2.18')
        im.BulletText('Native GTA-style clock, cash, bars and wanted stars')
        im.BulletText('Bitmap HUD fonts; original LuaHZ weapon icons retained')
        im.Spacing();im.TextUnformatted('LuaHZ 0.2.17')
        im.BulletText('Larger section headings and silent character fetching')
        im.Spacing();im.TextUnformatted('LuaHZ 0.2.16')
        im.BulletText('Character Status panel and configurable I shortcut')
        im.BulletText('One stats request after login and manual refresh')
        im.Spacing();im.TextUnformatted('LuaHZ 0.2.15');im.TextDisabled('2026-10-08')
        im.BulletText('Commands page identifies LuaHZ shortcuts and Horizon help')
        im.BulletText('Clearer descriptions and script reload command')
        im.Spacing();im.TextUnformatted('LuaHZ 0.2.14')
        im.BulletText('Quickmap keeps movement, driving and cruise active')
        im.BulletText('Correct turf colors and flashing; recover native zones')
        im.Spacing();im.TextUnformatted('LuaHZ 0.2.13')
        im.BulletText('One growing Horizon map catalog with uniform icons')
        im.Spacing();im.TextUnformatted('LuaHZ 0.2.9')
        im.BulletText('Server reload animation command on the reload hotkey')
        im.BulletText('Tighter dashboard dropdown and text-free menu icon')
        im.Spacing();im.TextUnformatted('LuaHZ 0.2.8')
        im.BulletText('Shared player/dashboard fonts, padding and bar sizes')
        im.BulletText('Dashboard layout adapts to larger text')
        im.Spacing();im.TextUnformatted('LuaHZ 0.2.7')
        im.BulletText('Dashboard dropdown fits all options without scrolling')
        im.BulletText('Badge removed; square bars across every HUD')
        im.Spacing();im.TextUnformatted('LuaHZ 0.2.6')
        im.BulletText('Padded dashboard options with equal row heights')
        im.BulletText('Thicker HUD bars and larger weapon icons')
        im.Spacing();im.TextUnformatted('LuaHZ 0.2.5')
        im.BulletText('Compact centered branding; scrollbars only when needed')
        im.BulletText('Double-size player HUD text trial with spaced rows')
        im.Spacing();im.TextUnformatted('LuaHZ 0.2.4')
        im.BulletText('Larger logo with spacing and stable tab widths')
        im.BulletText('Player HUD text increased by 16 percent')
        im.Spacing();im.TextUnformatted('LuaHZ 0.2.3')
        im.BulletText('Refined spacing, controls and US English labels')
        im.BulletText('Lucide notification icon on the blue badge')
        im.Spacing();im.TextUnformatted('LuaHZ 0.2.2')
        im.BulletText('Modifier combos for built-in and custom keybinds')
        im.BulletText('Hide Horizon health bar; remove ammo count')
        im.BulletText('Square sidebar edge and Lucide close icon')
        im.Spacing();im.TextUnformatted('LuaHZ 0.2.1')
        im.BulletText('Custom command keybinds and Lucide sidebar icons')
        im.BulletText('Energy bars share the bottom dashboard area')
        im.Spacing();im.TextUnformatted('LuaHZ 0.2.0')
        im.BulletText('Display scaling and adjustable HUD layout')
        im.BulletText('Magazine ammo and corrected Horizon health')
        im.BulletText('Live map opacity preview')
        im.Spacing()
        im.TextWrapped('Initial editable reconstruction of the LunaHZ 0.14.4 feature baseline.')
    elseif self.tab==9 then
        require('horizonbase.information_ui').draw(self)
    end
end

function M:draw()
    local im=self.im
    local w,h=getScreenResolution()
    local nextScale=logic.interfaceScale(w,h,self.prefs.interface.scale,logic.menuWidth)
    local layoutChanged=not self.scaleDragging and math.abs(nextScale-self.scale)>.001
    if layoutChanged then self:theme() end
    local S=self.scale
    im.SetNextWindowSize(im.ImVec2(logic.menuWidth*S,540*S),im.Cond.Always)
    im.SetNextWindowPos(im.ImVec2(w/2,h/2),layoutChanged and im.Cond.Always or im.Cond.FirstUseEver,im.ImVec2(.5,.5))
    im.Begin('##LuaHZSettings',self.open,im.WindowFlags.NoTitleBar + im.WindowFlags.NoCollapse + im.WindowFlags.NoResize + im.WindowFlags.NoScrollbar + im.WindowFlags.NoScrollWithMouse)
    im.SetWindowFontScale(1)
    local size=im.GetWindowSize();local pos=im.GetWindowPos();local dl=im.GetWindowDrawList()
    dl:AddRectFilled(pos,im.ImVec2(pos.x+187*S,pos.y+size.y),im.U32(.08,.095,.105,1),15*S)
    dl:AddRectFilled(im.ImVec2(pos.x+172*S,pos.y),im.ImVec2(pos.x+187*S,pos.y+size.y),im.U32(.08,.095,.105,1))
    local headerX=16*S;local headingX=90*S
    local logo=self.overlay and self.overlay:texture('ui-v0212/luahz-logo.png')
    if logo then dl:AddImage(logo,im.ImVec2(pos.x+headerX,pos.y+8*S),im.ImVec2(pos.x+headerX+64*S,pos.y+72*S)) end
    local lineHeight=im.GetFontSize()
    local headingY=40*S-(2*lineHeight+3*S)/2
    im.SetCursorPos(im.ImVec2(headingX,headingY));im.TextColored(im.ImVec4(1,.62,0,1),'LuaHZ')
    im.SetCursorPos(im.ImVec2(headingX,headingY+lineHeight+3*S));im.TextDisabled('0.4.0-rc.5')
    local sidebarOrder={1,2,3,4,5,6,9,7,8}
    local rowStep=math.min(42,(size.y/S-94-65-34)/(#tabs-1))
    for slot,i in ipairs(sidebarOrder) do
        local label=tabs[i]
        im.SetCursorPos(im.ImVec2(12*S,(94+(slot-1)*rowStep)*S))
        local row=im.GetCursorScreenPos()
        if im.InvisibleButton(label..'##tab',im.ImVec2(163*S,34*S)) then self.tab=i;self.capture=nil;self.previewMap=false;self.scaleDragging=false end
        local selected=i==self.tab
        if selected or im.IsItemHovered() then
            dl:AddRectFilled(row,im.ImVec2(row.x+163*S,row.y+34*S),selected and im.U32(.24,.18,.07,1) or im.U32(.13,.14,.16,1),7*S)
        end
        local color=selected and im.U32(1,.62,0,1) or im.U32(.58,.60,.65,1)
        local icon=self.overlay and self.overlay:texture('ui-v0212/'..tabIcons[i]..'.png')
        if icon then dl:AddImage(icon,im.ImVec2(row.x+10*S,row.y+8*S),im.ImVec2(row.x+28*S,row.y+26*S),im.ImVec2(0,0),im.ImVec2(1,1),color) end
        dl:AddText(im.ImVec2(row.x+39*S,row.y+(34*S-im.GetFontSize())/2),color,label)
    end
    im.SetCursorPos(im.ImVec2(12*S,size.y-51*S))
    if im.Button('Check files',im.ImVec2(79*S,27*S)) then self.checkRequested=true end
    im.SameLine()
    if im.Button('Reload',im.ImVec2(76*S,27*S)) then self.reloadRequested=true end
    im.SetCursorPos(im.ImVec2(size.x-35*S,10*S))
    local closePos=im.GetCursorScreenPos()
    if im.InvisibleButton('##closeSettings',im.ImVec2(25*S,25*S)) then self.open[0]=false;self.capture=nil end
    local closeColor=im.IsItemHovered() and im.U32(1,.62,0,1) or im.U32(.68,.70,.74,1)
    local closeIcon=self.overlay and self.overlay:texture('ui-v0212/x.png')
    if closeIcon then dl:AddImage(closeIcon,im.ImVec2(closePos.x+3*S,closePos.y+3*S),im.ImVec2(closePos.x+22*S,closePos.y+22*S),im.ImVec2(0,0),im.ImVec2(1,1),closeColor) end
    im.SetCursorPos(im.ImVec2(209*S,50*S))
    self.contentWidth=size.x-231*S-im.GetStyle().ScrollbarSize
    local pageId='##page'..self.tab..(self.tab==9 and '-'..self.horizonPage[0] or '')
    local pageFlags=self.tab==9 and (im.WindowFlags.NoScrollbar+im.WindowFlags.NoScrollWithMouse) or 0
    im.BeginChild(pageId,im.ImVec2(size.x-231*S,size.y-72*S),false,pageFlags)
    im.SetWindowFontScale(1)
    local ok,err=pcall(self.content,self)
    im.EndChild();im.End()
    if not ok then error(err) end
end

return M

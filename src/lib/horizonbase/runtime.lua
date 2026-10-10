-- HZ-only feature runtime. Loaded lazily by the endpoint bootstrap.
local M={}
function M.new(authorized,focusProvider)
local Config=require 'horizonbase.config'
local Logic=require 'horizonbase.logic'
local Keys=require 'horizonbase.keys'
local Server=require 'horizonbase.server'
local Game=require 'horizonbase.game'
local app={faults={},focused=true,started=false,audioHistory={}}
local ownedCommands,ownedEvents={},{}
local function sessionActive() return app.started and authorized() end
local root=getWorkingDirectory()
local configPath=root..'\\config\\horizonbase.ini'
local imported=Config.read(configPath)
local importSource='Existing Horizon Base preferences'
if not imported then
    imported=Config.read(root..'\\config\\lunahz.ini')
    importSource=imported and 'Imported LunaHZ preferences' or 'Default preferences'
end
local prefs=Config.validate(imported)

local function notify(text)
    print('[LuaHZ] '..text)
    if authorized() and isSampAvailable() then sampAddChatMessage('{FFAA22}[LuaHZ]{FFFFFF} '..text,-1) end
end
local function save()
    if not doesDirectoryExist(root..'\\config') then createDirectory(root..'\\config') end
    local ok,err=Config.save(configPath,prefs)
    if not ok then notify('Could not save preferences: '..tostring(err)) end
end
local function queueSave() app.saveDue=getGameTimer()+300 end

local function guard(component,fn,...)
    if app.faults[component] then return false end
    local ok,result=pcall(fn,...)
    if not ok then
        app.faults[component]=tostring(result)
        notify(component..' stopped after an error. Use /hbdebug for details and restart or reload after fixing it.')
        if app.toast then app.toast:push(component..' could not start. Use /hbdebug for details.','error') end
        print(debug.traceback(tostring(result)))
        if (component=='HUD' or component=='Native HUD') and app.overlay then app.overlay:restoreNative() end
        if component=='Menu' and app.ui then app.ui.open[0]=false;app.ui.capture=nil end
        if component=='Character Status' and app.status then app.status.open[0]=false end
        if component=='Game' and app.game then app.game:cleanup();app.game.sample={ready=false} end
        if component=='Quickmap' and app.overlay then app.overlay.mapOpen=false end
        if component=='Native Map' and app.nativeLocations then pcall(function()app.nativeLocations:cleanup()end)end
    end
    return ok,result
end

app.game=Game.new(prefs,notify)
app.catalog=require('horizonbase.location_catalog').new(root..'\\config\\luahz-locations')
app.server=Server.new(prefs,notify,getGameTimer,app.catalog)
app.gangZones=require('horizonbase.gang_zones').new(app.server)
app.nativeLocations=require('horizonbase.native_locations').new(app.server,prefs)
app.game.server=app.server
app.nativeVisuals=require('horizonbase.native_visuals').new(root..'\\resource\\horizonbase\\native-v0232',authorized)
local ok,im=pcall(require,'horizonbase.ui_backend')
if ok then
    app.im=im
    if im.SetActivationCheck then im.SetActivationCheck(sessionActive) end
    app.toast=require('horizonbase.toast').new(im,getGameTimer)
    app.ui=require('horizonbase.ui').new(im,prefs,queueSave,notify)
    app.overlay=require('horizonbase.overlay').new(im,prefs,app.game,app.server)
    app.ui.overlay=app.overlay
    app.status=require('horizonbase.character_ui').new(im,app.ui,app.server)
    app.toast.overlay=app.overlay
    im.OnInitialize(function()
        local resourcesStart=getGameTimer()
        local menuReady=guard('Menu',function() app.ui:theme() end)
        local resourcesReady=guard('Resources',function() app.overlay:initialize() end)
        app.interfaceReady=menuReady and resourcesReady
        print(('[LuaHZ] Essential interface resources initialized in %d ms; optional textures load across frames.'):format(getGameTimer()-resourcesStart))
    end)
    app.hudFrame=im.OnFrame(function()
        return sessionActive() and app.server.loginSeen and app.game.sample.ready and app.focused and not isPauseMenuActive() and
            not app.overlay.mapOpen and not app.ui:isMapPreview()
    end,function()
        local hudReady=guard('HUD',function() app.overlay:hud() end)
        if hudReady and app.toast:announce('0.2.39',app.faults,app.interfaceReady) then
            notify('0.2.39 loaded. Settings: /luahz or '..app.ui:keyName(prefs.keybinds.settingsPanel,prefs.modifiers.settingsPanel))
        end
    end)
    app.hudFrame.HideCursor=true;app.hudFrame.LockPlayer=false
    app.mapFrame=im.OnFrame(function()
        return sessionActive() and app.game.sample.ready and app.focused and
            (app.overlay.mapOpen or app.ui:isMapPreview()) and not isPauseMenuActive()
    end,function()
        app.overlay.preview=app.ui:isMapPreview()
        guard('Quickmap',function() app.overlay:map() end)
    end)
    app.mapFrame.HideCursor=true;app.mapFrame.LockPlayer=false
    app.menuFrame=im.OnFrame(function()
        return sessionActive() and app.game.sample.ready and app.focused and app.ui.open[0] and not isPauseMenuActive()
    end,function() guard('Menu',function() app.ui:draw() end) end)
    app.menuFrame.HideCursor=false;app.menuFrame.LockPlayer=true
    app.toastFrame=im.OnFrame(function()
        return sessionActive() and app.focused and app.toast:active() and not isPauseMenuActive()
    end,function() guard('Notifications',function() app.toast:draw() end) end)
    app.toastFrame.HideCursor=true;app.toastFrame.LockPlayer=false
    app.statusFrame=im.OnFrame(function()
        return sessionActive() and app.game.sample.ready and app.focused and app.status.open[0] and not isPauseMenuActive()
    end,function() guard('Character Status',function() app.status:draw() end) end)
    app.statusFrame.HideCursor=false;app.statusFrame.LockPlayer=true
    app.resourceFrame=im.OnFrame(function()
        return sessionActive() and app.interfaceReady and app.focused and not isPauseMenuActive() and app.overlay:warmupPending()
    end,function() guard('Resources',function() app.overlay:warmupStep() end) end)
    app.resourceFrame.HideCursor=true;app.resourceFrame.LockPlayer=false
else
    app.faults.Menu=tostring(im)
end

local function isTyping()
    return Game.call('sampIsChatInputActive',false) or Game.call('sampIsDialogActive',false)
end
local function blocked(allowMap)
    return not app.focused or isPauseMenuActive() or isTyping() or not app.game.sample.alive or
        app.status and app.status.open[0] or
        app.ui and (app.ui.open[0] or app.ui.capture or getGameTimer()<(app.ui.ignoreKeysUntil or 0)) or
        not allowMap and app.overlay and app.overlay.mapOpen
end
local function toggleMenu()
    if not app.ui or app.faults.Menu then notify('Settings UI unavailable. Use /hbdebug for the recorded error.');return end
    if app.status then app.status.open[0]=false end
    app.overlay.mapOpen=false;app.ui.open[0]=not app.ui.open[0];app.ui.capture=nil
end

local function toggleStatus()
    if not app.status or app.faults['Character Status'] then notify('Character Status UI unavailable. Use /luahzdebug.');return end
    app.ui.open[0]=false;app.ui.capture=nil;app.overlay.mapOpen=false
    app.status.open[0]=not app.status.open[0]
    if app.status.open[0] and not app.server.character.updatedAt then app.server:requestStats() end
end

local function window(msg,key,lparam)
    if not sessionActive() then return end
    if msg==0x0008 or msg==0x001C and key==0 then
        app.focused=false;app.game:cleanup()
        if app.ui then app.ui.open[0]=false;app.ui.capture=nil end
        if app.status then app.status.open[0]=false end
        if app.overlay then app.overlay.mapOpen=false end
        return
    elseif msg==0x0007 or msg==0x001C and key~=0 then app.focused=true end
    if not app.started or (msg~=0x0100 and msg~=0x0104) then return end
    if require('bit').band(lparam,0x40000000)~=0 then return end
    local mods=Keys.modifiers()
    if msg==0x0104 and require('bit').band(lparam,0x20000000)~=0 then mods=require('bit').bor(mods,4) end
    if app.ui and app.ui.capture and app.ui:captureKey(key,getGameTimer(),mods) then
        consumeWindowMessage(true,true,true);return
    end
    if key==27 and mods==0 then
        if app.status and app.status.open[0] then app.status.open[0]=false;consumeWindowMessage(true,true,true)
        elseif app.ui and app.ui.open[0] then app.ui.open[0]=false;consumeWindowMessage(true,true,true)
        elseif app.overlay and app.overlay.mapOpen then app.overlay.mapOpen=false;consumeWindowMessage(true,true,true) end
        return
    end
    if isTyping() or isPauseMenuActive() or not app.focused then return end
    if Keys.matches(prefs.keybinds.settingsPanel,prefs.modifiers.settingsPanel,key,mods) then toggleMenu();consumeWindowMessage(true,true,true)
    elseif app.status and app.game.sample.alive and Keys.matches(prefs.keybinds.characterStatus,prefs.modifiers.characterStatus,key,mods) then
        toggleStatus();consumeWindowMessage(true,true,true)
    elseif app.overlay and not (app.status and app.status.open[0]) and Keys.matches(prefs.keybinds.quickmap,prefs.modifiers.quickmap,key,mods) and not app.ui.open[0] then
        app.overlay.mapOpen=not app.overlay.mapOpen;consumeWindowMessage(true,true,true)
    end
end

local function keyPressed(code,mods) return Keys.pressed(code,mods) end
local function hotkeys()
    if blocked() then return end
    if keyPressed(prefs.keybinds.siren,prefs.modifiers.siren) then app.game:siren() end
    if keyPressed(prefs.keybinds.reload,prefs.modifiers.reload) and getGameTimer()>=(app.commandBindDue or 0) then
        local command=app.game:reload()
        if command then
            app.game.reloadGuard:begin(app.game.sample)
            sampSendChat(command);app.commandBindDue=getGameTimer()+300
        end
    end
    local cc=prefs.cruisecontrol
    if keyPressed(cc.toggleKey,prefs.modifiers.toggleKey) then app.game:toggleCruise() end
    for i=1,3 do if keyPressed(cc['preset'..i..'Key'],prefs.modifiers['preset'..i..'Key']) then app.game:toggleCruise(cc['preset'..i..'Speed']) end end
    if app.game.cruise.active then
        if keyPressed(107) or keyPressed(187) then app.game.cruise.target=math.min(200,app.game.cruise.target+1) end
        if keyPressed(109) or keyPressed(189) then app.game.cruise.target=math.max(1,app.game.cruise.target-1) end
    end
    for _,binding in ipairs(prefs.custombinds) do
        if keyPressed(binding.key,binding.mods) and getGameTimer()>=(app.commandBindDue or 0) then
            app.server:onOutgoing(binding.command)
            sampSendChat(binding.command)
            app.commandBindDue=getGameTimer()+300
            break
        end
    end
end

local function resolvePlayer(arg)
    arg=arg:gsub('^%s+',''):gsub('%s+$','')
    local id=tonumber(arg)
    if id and id==math.floor(id) and sampIsPlayerConnected(id) then return id,sampGetPlayerNickname(id) end
    local found,name
    local needle=Logic.normalizeName(arg)
    if needle=='' then return nil end
    for player=0,Game.call('sampGetMaxPlayerId',1004,false) do
        if sampIsPlayerConnected(player) then
            local nickname=sampGetPlayerNickname(player)
            local normalized=Logic.normalizeName(nickname)
            if normalized==needle then return player,nickname end
            if normalized:find(needle,1,true) then
                if found then return nil,'Ambiguous name. Use a player ID or full name.' end
                found,name=player,nickname
            end
        end
    end
    return found,name
end

local function diagnostics()
    print('[LuaHZ diagnostics] '..importSource)
    print('Font: '..tostring(app.im and app.im.FontSource or 'UI not initialized'))
    print('Horizon server detected: '..tostring(app.server.horizon))
    print('Player ready: '..tostring(app.game.sample.ready)..'; focused: '..tostring(app.focused))
    for _,entry in ipairs(app.server.character:diagnostics()) do print(entry) end
    print('Player appearance: skin='..tostring(app.game.sample.skin)..'; player ID='..tostring(app.game.sample.playerId))
    local reload=app.game.reloadGuard
    print('Reload: locked='..tostring(reload.active==true)..'; animation='..tostring(reload.anim)..'; observed='..tostring(reload.seen==true))
    print(app.nativeLocations:diagnostics())
    print(app.nativeVisuals:diagnostics())
    print('Last automated command: '..tostring(app.server.lastAction))
    print('HUD data: health='..tostring(app.game.sample.health)..'; raw health='..tostring(app.game.sample.rawHealth)..
        '; wanted='..tostring(app.game.sample.wanted)..'; clip='..tostring(app.game.sample.ammoClip)..
        '; engine total='..tostring(app.game.sample.ammoTotal))
    for _,entry in ipairs(app.audioHistory) do print('[Audio trace] '..entry) end
    for _,entry in ipairs(app.game.ammoHistory) do print('[Ammo trace] '..entry) end
    for _,entry in ipairs(require('horizonbase.map_icons').diagnostics(app.server.icons)) do print(entry) end
    if app.game.sample.ready then app.gangZones:sync(getGameTimer(),true) end
    for _,entry in ipairs(require('horizonbase.gang_zones').diagnostics(app.server.zones)) do print(entry) end
    if app.gangZones.error then print('[Gang zones] '..app.gangZones.error) end
    print('[Location catalog] server='..tostring(app.catalog.address)..'; saved='..#app.catalog.records..'; file='..tostring(app.catalog.path))
    if app.catalog.error then print('[Location catalog] '..app.catalog.error) end
    for component,error in pairs(app.faults) do print(component..': '..error) end
    for name in pairs({['mimgui.imgui']=true, ['samp.events']=true}) do print('Dependency loaded: '..name..'='..tostring(package.loaded[name]~=nil)) end
    for _,text in ipairs(app.server.recent) do print('[Recent server message] '..text) end
    notify('Component status and recent server messages written to moonloader.log.')
end

local function registerCommands()
    local function register(name,callback)
        sampRegisterChatCommand(name,function(...)
            if sessionActive() then return callback(...) end
        end)
        ownedCommands[name]=true
    end
    register('lsettings',toggleMenu)
    register('hbase',toggleMenu)
    register('luahz',toggleMenu)
    register('luahzstatus',toggleStatus)
    register('hbdebug',diagnostics)
    register('hbreload',function() app.reloadRequested=true end)
    register('luahzdebug',diagnostics)
    register('luahzreload',function() app.reloadRequested=true end)
    for command,key in pairs({togrepair='repair',toglawyer='lawyer',togwhore='whore',togdrugs='drugs',togtaxi='taxi'}) do
        local field=key
        register(command,function()
            prefs.togs[field]=not prefs.togs[field];save()
            if app.ui then app.ui:refreshControls() end
            notify(field..' auto-accept '..(prefs.togs[field] and 'enabled' or 'disabled'))
        end)
    end
    for command,key in pairs({togoxygen='oxygen',togstamina='stamina'}) do
        local field=key
        register(command,function()
            prefs.settings[field]=not prefs.settings[field];save()
            if app.ui then app.ui:refreshControls() end
            notify(field..' display '..(prefs.settings[field] and 'enabled' or 'disabled'))
        end)
    end
    register('lvdb',function(arg)
        local n=tonumber(arg)
        if not n or n~=math.floor(n) or n<0 or n>2 then notify('Usage: /lvdb 0 (off), 1 (full), or 2 (minimal)');return end
        prefs.settings.vdb=n;save();if app.ui then app.ui:refreshControls() end
    end)
    register('togs',function()
        local parts={}
        for _,key in ipairs({'repair','lawyer','whore','drugs','taxi'}) do parts[#parts+1]=key..'='..(prefs.togs[key] and 'ON' or 'OFF') end
        notify(table.concat(parts,' | '))
    end)
    register('autofind',function(arg)
        arg=arg or ''
        if arg:match('^%s*$') then
            app.server.find.active=false;notify('Autofind stopped.');return
        end
        local id,name=resolvePlayer(arg)
        if not id then notify(name or 'Player not found. Use an online player ID or name.');return end
        app.server:startFind(id,name)
    end)
    register('autotrackcar',function() app.server:toggleTrack() end)
end

local function hookEvents()
    local events=require 'samp.events'
    local previous={}
    for _,name in ipairs({'onPlayAudioStream','onStopAudioStream','onServerMessage','onSendCommand','onApplyPlayerAnimation','onClearPlayerAnimation','onShowDialog','onSendDialogResponse','onCreateGangZone','onGangZoneDestroy','onGangZoneFlash','onGangZoneStopFlash','onSetMapIcon','onRemoveMapIcon','onSetCheckpoint','onDisableCheckpoint','onShowTextDraw','onTextDrawSetString','onTextDrawHide','onGamemodeRestart','onPlayerQuit','onPlayerJoin'}) do previous[name]=events[name] end
    local function audioTrace(text)
        local entry=('t=%d %s'):format(getGameTimer(),text)
        app.audioHistory[#app.audioHistory+1]=entry
        if #app.audioHistory>12 then table.remove(app.audioHistory,1) end
        print('[Audio trace] '..entry)
    end
    -- Observe only: nil returns preserve normal client stream playback.
    function events.onPlayAudioStream(url,position,radius,usePosition)
        audioTrace('server play '..url..'; positional='..tostring(usePosition))
    end
    function events.onStopAudioStream() audioTrace('server stop') end
    function events.onServerMessage(_,text)
        local success,hide=guard('Server',function() return app.server:onMessage(text) end)
        if success and hide then return false end
    end
    function events.onSendCommand(command) guard('Server',function() app.server:onOutgoing(command) end) end
    function events.onApplyPlayerAnimation(playerId,animLib,animName)
        guard('Game',function()app.game.reloadGuard:onAnimation(playerId,animName)end)
    end
    function events.onClearPlayerAnimation(playerId)
        guard('Game',function()app.game.reloadGuard:onClear(playerId)end)
    end
    function events.onShowDialog(id,style,title,_,_,text)
        local success,hide=guard('Server',function() return app.server:onDialog(id,title,text,style) end)
        if success and hide then return false end
    end
    function events.onSendDialogResponse(id,button,list,input) guard('Server',function() app.server:onDialogResponse(id,button,list,input) end) end
    function events.onCreateGangZone(id,startPos,endPos,color) app.server.zones[id]={min=startPos,max=endPos,color=color} end
    function events.onGangZoneDestroy(id) app.server.zones[id]=nil end
    function events.onGangZoneFlash(id,color) if app.server.zones[id] then app.server.zones[id].flashColor=color end end
    function events.onGangZoneStopFlash(id) if app.server.zones[id] then app.server.zones[id].flashColor=nil end end
    function events.onSetMapIcon(id,position,kind,color,style) app.server:onMapIcon(id,position,kind,color,style) end
    function events.onRemoveMapIcon(id) app.server:removeMapIcon(id) end
    function events.onSetCheckpoint(position) app.server.checkpoint=position end
    function events.onDisableCheckpoint() app.server.checkpoint=nil end
    function events.onShowTextDraw(id,td)
        app.server:onTextdraw(id,td.text or '')
        if app.overlay then
            local ok,result=guard('Native HUD',function() return app.overlay.serverHud:onShow(id,td,app.server.horizon) end)
            if ok then return result end
        end
    end
    function events.onTextDrawSetString(id,text) app.server:onTextdraw(id,text) end
    function events.onTextDrawHide(id) app.server.textdraws[id]=nil;if app.overlay then app.overlay.serverHud.positions[id]=nil end end
    function events.onGamemodeRestart()
        app.server:reset();app.server.horizon=true;app.game:cleanup()
        app.game.sample={ready=false,alive=false}
        if app.ui then app.ui.open[0]=false;app.ui.capture=nil;app.ui.previewMap=false end
        if app.status then app.status.open[0]=false end
        if app.overlay then app.overlay.mapOpen=false;app.overlay:restoreNative() end
        app.nativeLocations:cleanup()
    end
    function events.onPlayerQuit(id)
        if app.server.find.active and tostring(id)==app.server.find.id then
            app.server.find.paused=true;app.server.find.description='Target disconnected; waiting for rejoin.'
        end
    end
    function events.onPlayerJoin(id,color,isNpc,name)
        if app.server.find.active and Logic.normalizeName(name)==Logic.normalizeName(app.server.find.name) then
            app.server.find.id=tostring(id);app.server.find.paused=false;app.server.find.nextAt=getGameTimer()+3000
        end
    end
    for _,name in ipairs({'onPlayAudioStream','onStopAudioStream','onServerMessage','onSendCommand','onApplyPlayerAnimation','onClearPlayerAnimation','onShowDialog','onSendDialogResponse','onCreateGangZone','onGangZoneDestroy','onGangZoneFlash','onGangZoneStopFlash','onSetMapIcon','onRemoveMapIcon','onSetCheckpoint','onDisableCheckpoint','onShowTextDraw','onTextDrawSetString','onTextDrawHide','onGamemodeRestart','onPlayerQuit','onPlayerJoin'}) do
        local handler=events[name]
        local wrapper=function(...)
            if sessionActive() then return handler(...) end
        end
        ownedEvents[name]={module=events,wrapper=wrapper,previous=previous[name]}
        events[name]=wrapper
    end
end

local function closePanels()
    if app.ui then app.ui.open[0]=false;app.ui.capture=nil;app.ui.previewMap=false end
    if app.status then app.status.open[0]=false end
    if app.overlay then app.overlay.mapOpen=false;app.overlay.preview=false end
end

local function stop()
    if not app.started then return end
    if app.saveDue then pcall(save) end
    app.started=false
    for name in pairs(ownedCommands) do pcall(sampUnregisterChatCommand,name) end
    ownedCommands={}
    for name,entry in pairs(ownedEvents) do
        if entry.module[name]==entry.wrapper then entry.module[name]=entry.previous end
    end
    ownedEvents={}
    closePanels()
    if app.im and app.im.Suspend then app.im.Suspend() end
    pcall(function()app.nativeVisuals:stop()end)
    if app.overlay then pcall(function()app.overlay:restoreNative(not authorized())end) end
    if app.nativeLocations then pcall(function()app.nativeLocations:cleanup()end) end
    pcall(function()app.game:cleanup()end)
    pcall(function()app.server:reset()end)
    app.game.sample={ready=false,alive=false};app.game.ammoHistory={};app.game.lastAmmo=nil
    app.game.maxStamina=0;app.game.maxBreath=0
    app.audioHistory={};app.wasReady=false;app.commandBindDue=nil;app.saveDue=nil
    app.reloadRequested=false
    if app.toast then app.toast.queue={};app.toast.current=nil;app.toast.announced=false end
    if app.limiter then app.limiter.last=nil;app.limiter.limit=0 end
    print('[LuaHZ] HZ session ended; commands, UI and game overrides released.')
end

local function start()
    if app.started or not authorized() then return end
    app.focused=not focusProvider or focusProvider()
    app.started=true;app.server.horizon=true
    app.nativeVisuals:activate()
    guard('Server',hookEvents)
    save();registerCommands()
    if not app.limiter then
        local ok,limiter=pcall(function()return require('horizonbase.limiter').new()end)
        if ok then app.limiter=limiter else app.faults.Limiter=tostring(limiter) end
    end
    print('[LuaHZ] 0.2.39 authorized endpoint 213.32.6.232:7777; waiting for login.')
end

local function tick()
    if not sessionActive() then stop();return end
    if focusProvider then app.focused=focusProvider() end
        guard('Game',function()
            app.game:refresh();app.game.reloadGuard:update(app.game.sample,app.focused)
            hotkeys();app.game:drive(blocked(true))
        end)
        if not app.game.sample.ready then
            if app.wasReady and Game.call('sampGetGamestate',5)~=3 then
                app.server:reset();app.server.horizon=true
                if app.ui then app.ui.open[0]=false;app.ui.capture=nil end
        if app.status then app.status.open[0]=false end
                if app.overlay then app.overlay.mapOpen=false end
            end
            if app.overlay then app.overlay:restoreNative() end
        end
        app.wasReady=app.game.sample.ready
        if app.saveDue and getGameTimer()>=app.saveDue then app.saveDue=nil;save() end
        app.server.ready=app.game.sample.ready and app.game.sample.alive and app.focused
        if app.game.sample.ready then
            local id=app.game.sample.playerId or -1
            app.server.characterName=id>=0 and Game.call('sampGetPlayerNickname','',id) or nil
        end
        app.server.horizon=true
        if app.game.sample.ready and app.server.horizon then
                local directory=root..'\\config\\luahz-locations'
                if not app.catalogDirectoryReady then
                    if not doesDirectoryExist(directory) then createDirectory(directory) end
                    app.catalogDirectoryReady=doesDirectoryExist(directory)
                end
                local _,err=app.server:bindLocations()
                if err and err~=app.catalogNotice then notify('Could not load saved locations: '..tostring(err));app.catalogNotice=err end
        end
        local catalogOk,catalogError=app.catalog:update()
        if not catalogOk and catalogError~=app.catalogNotice then
            notify('Could not save locations: '..tostring(catalogError));app.catalogNotice=catalogError
        elseif catalogOk and not app.catalog.error then app.catalogNotice=nil end
        if app.overlay then
            if app.game.sample.ready and prefs.quickmap.gangzones and
                (app.overlay.mapOpen or app.ui:isMapPreview()) then app.gangZones:sync(getGameTimer()) end
            guard('Native HUD',function()
                app.overlay:updateNative(app.game.sample.ready and app.focused and not isPauseMenuActive() and not app.faults.HUD)
            end)
        end
        guard('Server',function() app.server:update(sampSendChat,sampSendDialogResponse,not isTyping() and not isPauseMenuActive() and
            not (app.ui and app.ui.open[0]) and not (app.overlay and app.overlay.mapOpen)) end)
        if app.ui then
            if app.ui.checkRequested then app.ui.checkRequested=false;diagnostics() end
            if app.ui.reloadRequested then app.ui.reloadRequested=false;app.reloadRequested=true end
        end
    if app.reloadRequested then save();thisScript():reload();return end
end

local function present()
    if not sessionActive() then return end
    local visualsOk=guard('Native Visuals',function()app.nativeVisuals:update()end)
    if not visualsOk then pcall(function()app.nativeVisuals:stop()end) end
    if app.started and app.nativeLocations then
        guard('Native Map',function()
            app.nativeLocations:sync(getGameTimer(),app.game.sample,app.focused and isPauseMenuActive())
        end)
    end
    if app.started and app.limiter then
        local active=app.focused and app.game.sample.ready and not isPauseMenuActive()
        guard('Limiter',function() app.limiter:present(prefs.fps[Logic.context(app.game.sample)],active) end)
    end
end

local function terminate()
    if app.started then pcall(save) end
    stop()
    pcall(function()app.nativeVisuals:cleanup()end)
    if app.overlay then pcall(function()app.overlay:cleanup()end) end
end
return {start=start,stop=stop,tick=tick,present=present,window=window,terminate=terminate}
end
return M

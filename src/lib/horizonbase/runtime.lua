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
local queueQuickAction,onlinePlayers
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
        if component=='Vehicle' then
            if app.vehicleUI then app.vehicleUI:reset()end
            if app.vehicle then app.vehicle:reset()end
            app.quickRequest=nil
        end
        if component=='Quick Actions' then
            if app.actions then app.actions:reset()end
            app.quickRequest=nil
        end
        if component=='Game' and app.game then app.game:cleanup();app.game.sample={ready=false} end
        if component=='Quickmap' and app.overlay then app.overlay.mapOpen=false end
        if component=='Native Map' and app.nativeLocations then pcall(function()app.nativeLocations:cleanup()end)end
        if component=='Observations' and app.observations then pcall(function()app.observations:stop('observer error')end)end
    end
    return ok,result
end

app.game=Game.new(prefs,notify)
app.catalog=require('horizonbase.location_catalog').new(root..'\\config\\luahz-locations')
app.server=Server.new(prefs,notify,getGameTimer,app.catalog,function(text,kind,key)
    if sessionActive() and app.toast and app.interfaceReady and not app.faults.Notifications then
        app.toast:push(text,kind or 'error',key or 'vehicle-lock-result')
    else notify(text)end
end)
app.observations=require('horizonbase.observations').new(getGameTimer,notify)
app.vehicle=require('horizonbase.vehicle').new(getGameTimer,function(...)if sessionActive()then app.server.actionNotify(...)end end)
app.game.vehicleInfo=app.vehicle
local captureSerial=0
local function captureAction(action)
    local o=app.observations
    if action=='off' then app.captureRequest=nil;o:stop('user stopped');return end
    if action=='status' then
        notify('Capture '..(o.active and 'enabled' or 'off')..'; '..tostring(o.path or 'no capture file'));return
    end
    local command=require('horizonbase.observations').requestCommand(action)
    if action~='on' and action~='vehicles' and not command then
        notify('Usage: /luahzcapture vehicles|on|off|status, or families|rules|members|info|settings|myguns|help|carhelp. Vehicle actions are observed only when you perform them.');return
    end
    if app.captureRequest or o.active and command then notify('Finish the current capture first, or use /luahzcapture off.');return end
    if o.active then notify('Capture is already enabled.');return end
    if not sessionActive() or not app.server.loginSeen or not app.game.sample.ready then
        notify('Log in to Horizon before enabling command capture.');return
    end
    local directory=root..'\\config\\luahz-observations'
    if not doesDirectoryExist(directory) then createDirectory(directory) end
    if not doesDirectoryExist(directory) then notify('Could not create the capture folder.');return end
    local path
    repeat
        captureSerial=captureSerial+1
        path=directory..'\\capture-'..os.date('%Y%m%d-%H%M%S')..'-'..getGameTimer()..'-'..captureSerial..'.jsonl'
        local existing=io.open(path,'rb')
        if existing then existing:close() else break end
    until captureSerial>10000
    if captureSerial>10000 then notify('Could not choose a new capture filename.');return end
    local file,err=io.open(path,'wb')
    if not file then notify('Could not open capture file: '..tostring(err));return end
    local started,errorText=o:start(function(line)
        local written,errorMessage=file:write(line)
        if not written then return nil,errorMessage end
        return file:flush()
    end,function()return file:close()end,path,action=='vehicles' and 'vehicles' or nil)
    if started then
        if command then
            app.captureRequest={command=command,expires=getGameTimer()+10000}
            o.single=true
            notify('Queued '..command..' capture. It runs once when gameplay is ready and stops after 8 seconds.')
        elseif action=='vehicles' then
            notify('Vehicle capture enabled for up to five minutes. Enter vehicles or use /car, /vstorage or /trackcar yourself; /luahzcapture off stops it.')
        else notify('Manual capture enabled for up to five minutes. Run a supported command; /luahzcapture off stops it.') end
        notify('Capture file: '..path)
    elseif errorText then notify(errorText) end
end
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
    app.ui.server=app.server
    app.ui.observations=app.observations
    app.ui.captureAction=function(action)guard('Observations',function()captureAction(action)end)end
    app.overlay=require('horizonbase.overlay').new(im,prefs,app.game,app.server)
    app.ui.overlay=app.overlay
    app.status=require('horizonbase.character_ui').new(im,app.ui,app.server)
    app.actions=require('horizonbase.actions_ui').new(im,app.ui,app.server,function(kind,arg)return queueQuickAction(kind,arg)end,function()return onlinePlayers()end)
    app.vehicleUI=require('horizonbase.vehicle_ui').new(im,app.ui,app.vehicle,app.server,function(kind,arg)return queueQuickAction(kind,arg)end)
    app.toast.overlay=app.overlay
    app.toast.hudVisible=function()
        return sessionActive() and app.server.loginSeen and app.game.sample.ready and app.focused and not isPauseMenuActive()
            and not app.overlay.mapOpen and not app.ui:isMapPreview() and not app.faults.HUD
    end
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
        if hudReady and app.toast:announce('0.4.0',app.faults,app.interfaceReady) then
            notify('0.4.0 loaded. Settings: /luahz or '..app.ui:keyName(prefs.keybinds.settingsPanel,prefs.modifiers.settingsPanel))
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
    app.actionsFrame=im.OnFrame(function()
        return sessionActive() and app.server.loginSeen and app.game.sample.ready and app.game.sample.alive and app.focused and app.actions.open[0] and not isPauseMenuActive()
    end,function()guard('Quick Actions',function()app.actions:draw()end)end)
    app.actionsFrame.HideCursor=false;app.actionsFrame.LockPlayer=true
    app.vehicleFrame=im.OnFrame(function()
        return sessionActive() and app.server.loginSeen and app.game.sample.ready and app.game.sample.alive and app.focused and app.vehicleUI.open[0] and not Game.call('sampIsChatInputActive',false) and not Game.call('sampIsDialogActive',false) and not isPauseMenuActive()
    end,function()guard('Vehicle',function()app.vehicleUI:draw()end)end)
    app.vehicleFrame.HideCursor=true;app.vehicleFrame.LockPlayer=false;app.vehicleFrame.PassKeyboard=true
else
    app.faults.Menu=tostring(im)
end

local function isTyping()
    return Game.call('sampIsChatInputActive',false) or Game.call('sampIsDialogActive',false)
end
local function blocked(allowMap,allowVehicle)
    return not app.focused or isPauseMenuActive() or isTyping() or not app.game.sample.alive or
        not allowVehicle and app.vehicleUI and app.vehicleUI.open[0] and app.vehicleUI.cursor or
        app.actions and app.actions.open[0] or
        app.status and app.status.open[0] or
        app.ui and (app.ui.open[0] or app.ui.capture or getGameTimer()<(app.ui.ignoreKeysUntil or 0)) or
        not allowMap and app.overlay and app.overlay.mapOpen
end
local function toggleMenu()
    if not app.ui or app.faults.Menu then notify('Settings UI unavailable. Use /hbdebug for the recorded error.');return end
    if app.status then app.status.open[0]=false end
    if app.vehicleUI then app.vehicleUI:reset()end
    if app.actions then app.actions:reset()end
    app.overlay.mapOpen=false;app.ui.open[0]=not app.ui.open[0];app.ui.capture=nil
end

local function toggleStatus()
    if not app.status or app.faults['Character Status'] then notify('Character Status UI unavailable. Use /luahzdebug.');return end
    app.ui.open[0]=false;app.ui.capture=nil;app.overlay.mapOpen=false
    if app.vehicleUI then app.vehicleUI:reset()end
    if app.actions then app.actions:reset()end
    app.status.open[0]=not app.status.open[0]
    if app.status.open[0] and not app.server.character.updatedAt then app.server:requestStats() end
end
local function toggleActions()
    if not app.actions or app.faults['Quick Actions'] or not app.server.loginSeen or not app.game.sample.ready or not app.game.sample.alive then return end
    local opening=not app.actions.open[0];app.actions:reset();app.actions.open[0]=opening
    if app.vehicleUI then app.vehicleUI:reset()end
    if app.status then app.status.open[0]=false end
    if app.ui then app.ui.open[0]=false;app.ui.capture=nil end
    if app.overlay then app.overlay.mapOpen=false end
    app.server:cancelSequence()
end

local function toggleVehicle()
    if not app.vehicleUI or app.faults.Vehicle or not app.server.loginSeen or not app.game.sample.ready or not app.game.sample.alive or not app.focused or isPauseMenuActive() then return end
    local opening=not app.vehicleUI.open[0];app.vehicleUI:reset();app.vehicleUI.open[0]=opening
    if opening then app.vehicleUI.page=app.vehicle.current and 1 or 2 end
    if app.actions then app.actions:reset()end
    if app.status then app.status.open[0]=false end
    if app.ui then app.ui.open[0]=false;app.ui.capture=nil end
    if app.overlay then app.overlay.mapOpen=false end
    app.quickRequest=nil;app.server:cancelSequence()
end

local function window(msg,key,lparam)
    if not sessionActive() then return end
    if msg==0x0008 or msg==0x001C and key==0 then
        app.focused=false;app.game:cleanup()
        if app.vehicleUI then app.vehicleUI:reset()end
        app.vehicle.pending=nil
        app.server:cancelSequence()
        if app.actions then app.actions:reset()end
        app.quickRequest=nil
        app.observations:stop('window lost focus')
        app.captureRequest=nil
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
    if key==27 and (mods==0 or app.vehicleUI and app.vehicleUI.open[0]) then
        if app.vehicleUI and app.vehicleUI.open[0] then app.vehicleUI:reset();consumeWindowMessage(true,true,true)
        elseif app.actions and app.actions.open[0] then app.actions:reset();consumeWindowMessage(true,true,true)
        elseif app.status and app.status.open[0] then app.status.open[0]=false;consumeWindowMessage(true,true,true)
        elseif app.ui and app.ui.open[0] then app.ui.open[0]=false;consumeWindowMessage(true,true,true)
        elseif app.overlay and app.overlay.mapOpen then app.overlay.mapOpen=false;consumeWindowMessage(true,true,true) end
        return
    end
    if key==13 and app.focused and not Game.call('isPauseMenuActive',false) and Game.call('sampIsChatInputActive',false) then
        app.quickRequest=nil;app.vehicle.pending=nil
        guard('Server',function()app.server:noteManualCommand(Game.call('sampGetChatInputText',''))end)
    end
    if isTyping() or isPauseMenuActive() or not app.focused then return end
    if Keys.matches(prefs.keybinds.settingsPanel,prefs.modifiers.settingsPanel,key,mods) then toggleMenu();consumeWindowMessage(true,true,true)
    elseif app.vehicleUI and app.ui and app.overlay and app.server.loginSeen and app.game.sample.ready and app.game.sample.alive and Keys.matches(prefs.keybinds.vehicleMenu,prefs.modifiers.vehicleMenu,key,mods) and not app.ui.open[0] and not(app.status and app.status.open[0]) and not(app.actions and app.actions.open[0]) and not app.overlay.mapOpen then
        toggleVehicle();consumeWindowMessage(true,true,true)
    elseif not(app.vehicleUI and app.vehicleUI.open[0]) and app.actions and app.ui and app.overlay and app.server.loginSeen and app.game.sample.ready and app.game.sample.alive and Keys.matches(prefs.keybinds.quickActions,prefs.modifiers.quickActions,key,mods) and not app.ui.open[0] and not(app.status and app.status.open[0]) and not app.overlay.mapOpen then
        if not (app.actions and app.actions.open[0] and app.actions.findMode) then toggleActions();consumeWindowMessage(true,true,true)end
    elseif not(app.vehicleUI and app.vehicleUI.open[0]) and app.status and app.game.sample.alive and not (app.ui and app.ui.open[0]) and not(app.actions and app.actions.open[0]) and Keys.matches(prefs.keybinds.characterStatus,prefs.modifiers.characterStatus,key,mods) then
        toggleStatus();consumeWindowMessage(true,true,true)
    elseif not(app.vehicleUI and app.vehicleUI.open[0]) and app.overlay and not (app.status and app.status.open[0]) and not(app.actions and app.actions.open[0]) and Keys.matches(prefs.keybinds.quickmap,prefs.modifiers.quickmap,key,mods) and not app.ui.open[0] then
        app.overlay.mapOpen=not app.overlay.mapOpen;consumeWindowMessage(true,true,true)
    end
end

local function keyPressed(code,mods) return Keys.pressed(code,mods) end
local function hotkeys()
    if blocked(false,true) then app.server:cancelSequence();return end
    if app.vehicleUI and app.vehicleUI.open[0] and app.vehicleUI.cursor then return end
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
            if binding.command2 then
                app.server:requestSequence(binding)
            else
                app.server:cancelSequence()
                app.server:onOutgoing(binding.command,false)
                guard('Observations',function()app.observations:onOutgoing(binding.command,'keybind')end)
                guard('Vehicle',function()app.vehicle:onOutgoing(binding.command,false)end)
                sampSendChat(binding.command)
            end
            app.commandBindDue=getGameTimer()+300
            break
        end
    end
end

local function resolvePlayer(arg)
    arg=arg:gsub('^%s+',''):gsub('%s+$','')
    local id=tonumber(arg)
    if id then
        if id==math.floor(id) and id>=0 and id<=1004 and sampIsPlayerConnected(id)then return id,sampGetPlayerNickname(id)end
        return nil,'That player ID is not online.'
    end
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

onlinePlayers=function()
    local rows={}
    for id=0,math.min(1004,Game.call('sampGetMaxPlayerId',1004,false))do
        if id~=app.game.sample.playerId and sampIsPlayerConnected(id)then rows[#rows+1]={id=id,name=sampGetPlayerNickname(id)}end
    end
    return rows
end
queueQuickAction=function(kind,arg)
    if not sessionActive() or not app.server.loginSeen or not app.server.ready or not app.focused or isTyping() or isPauseMenuActive()then return false,'Actions require active Horizon gameplay.'end
    if app.quickRequest then return false,'Another action is queued.'end
    if not ({clear=true,lock=true,track=true,storage=true,vehicleControl=true,cargo=true,general=true,job=true,find=true,stopFind=true})[kind]then return false,'Unknown action.'end
    if app.server.clearNavigation and kind~='stopFind' and not(kind=='track' and app.server.track.active)then return false,'Navigation clear is awaiting confirmation.'end
    if kind=='vehicleControl' then
        if not require('horizonbase.vehicle').command(arg) then return false,'Unknown vehicle control.'end
        local available,reason=app.vehicle:available(arg);if not available then return false,reason end
    elseif kind=='cargo' then
        if app.game.sample.vehicle then return false,'Exit the vehicle first.'end
        if app.vehicle.pending then return false,'A vehicle change is awaiting confirmation.'end
    elseif kind=='find' and not require('horizonbase.job_actions').has(app.server.character,'detective') then
        return false,'Your current job is not Detective. Refresh your character stats.'
    elseif kind=='general' then
        if not ({skills=true,findjob=true,jobhelp=true})[arg] then return false,'Unknown action.'end
    elseif kind=='job' then
        local Jobs=require('horizonbase.job_actions')
        local spec=type(arg)=='table' and Jobs.get(app.server.character,arg.id)
        if not spec then return false,'Job action unavailable.'end
        local target,name
        if spec.mode=='target' or spec.mode=='price'then
            target,name=resolvePlayer(type(arg.target)=='string' and arg.target or '')
            if not target or target==app.game.sample.playerId then return false,name or 'Choose another online player.'end
        end
        local command,reason=Jobs.command(app.server.character,arg.id,target,arg.value)
        if not command then return false,reason end
        arg={id=arg.id,target=target and tostring(target),name=name,value=arg.value}
    end
    local footVehicleAction=not app.game.sample.vehicle and (kind=='vehicleControl' or kind=='lock' or kind=='cargo')
    app.quickRequest={kind=kind,arg=arg,vehicleEpoch=(kind=='vehicleControl' or kind=='lock' or kind=='cargo') and app.vehicle:token() or nil,
        anchor=footVehicleAction and {x=app.game.sample.x,y=app.game.sample.y,z=app.game.sample.z}or nil,expires=getGameTimer()+3000}
    return true
end
local function executeQuickAction()
    local request=app.quickRequest;if not request then return end
    if (request.kind=='vehicleControl' or request.kind=='storage' or request.kind=='cargo' or request.kind=='job' or request.kind=='general') and getGameTimer()-app.server.lastSend<1200 and getGameTimer()<request.expires and not blocked(false,true)then return end
    app.quickRequest=nil
    if not sessionActive() or getGameTimer()>=request.expires or blocked(false,true) or not app.server.ready or not app.server.loginSeen then
        app.server.actionNotify('Action canceled before sending.','error','quick-actions');return
    end
    local anchor=request.anchor;local sample=app.game.sample
    if anchor and ((anchor.x-sample.x)^2+(anchor.y-sample.y)^2+(anchor.z-sample.z)^2>9)then
        app.server.actionNotify('You moved away before sending. Action canceled.','error','vehicle-controls');return
    end
    local ok=true;local errorText
    if request.kind=='clear' then ok=app.server:requestClearNavigation()
    elseif request.kind=='lock' then
        if request.vehicleEpoch~=app.vehicle:token() then
            app.server.actionNotify('Vehicle changed before sending. Action canceled.','error','vehicle-controls');return
        end
        local family=app.vehicle.current and app.vehicle.current.ownership=='family'
        ok=app.server:requestSequence({command=family and '/gvl' or '/pvl',command2=family and '/pvl' or '/gvl'})
    elseif request.kind=='storage' or request.kind=='vehicleControl' or request.kind=='cargo' then
        local command='/vstorage'
        if request.kind=='vehicleControl' or request.kind=='cargo' then
            if request.vehicleEpoch~=app.vehicle:token() or request.kind=='vehicleControl' and not app.vehicle:available(request.arg) or request.kind=='cargo' and app.game.sample.vehicle then
                app.server.actionNotify('Vehicle changed before sending. Action canceled.','error','vehicle-controls');return
            end
            command=request.kind=='cargo' and '/trunkbalance' or require('horizonbase.vehicle').command(request.arg)
        end
        app.server:cancelSequence();app.server:onOutgoing(command,false)
        app.observations:onOutgoing(command,'vehicle menu');app.vehicle:onOutgoing(command,request.kind=='vehicleControl' or request.kind=='cargo')
        sampSendChat(command);app.server.lastSend=getGameTimer();app.server.lastAction=command
    elseif request.kind=='general' or request.kind=='job' then
        local command
        if request.kind=='general' then
            if ({skills=true,findjob=true,jobhelp=true})[request.arg]then command='/'..request.arg end
        else
            local arg=request.arg;local target=arg.target
            local spec=require('horizonbase.job_actions').get(app.server.character,arg.id)
            if spec and (spec.mode=='target' or spec.mode=='price')then
                local id,name=resolvePlayer(type(target)=='string' and target or '')
                if not id or id==app.game.sample.playerId then errorText=name or 'Choose another online player.'
                elseif arg.name and arg.name~=name then errorText='That player changed. Choose again.'
                else target=id end
            end
            if not errorText then command,errorText=require('horizonbase.job_actions').command(app.server.character,arg.id,target,arg.value)end
        end
        if command then
            app.server:cancelSequence();app.server:onOutgoing(command,false);sampSendChat(command)
            app.server.lastSend=getGameTimer();app.server.lastAction=command
        else ok=false end
    elseif request.kind=='track' then ok=app.server:toggleTrack(true)
    elseif request.kind=='stopFind' then app.server:stopFind();app.server.actionNotify('Player finding stopped.','info','quick-actions')
    elseif request.kind=='find' then
        if not require('horizonbase.job_actions').has(app.server.character,'detective')then app.server.actionNotify('Detective job is no longer active.','error','quick-actions');return end
        local id,name
        if type(request.arg)=='table' then
            local row=request.arg
            if type(row.id)=='number' and row.id==math.floor(row.id) and row.id>=0 and row.id<=1004 and sampIsPlayerConnected(row.id) and sampGetPlayerNickname(row.id)==row.name then id,name=row.id,row.name
            else errorText='That player is no longer available. Choose again.'end
        elseif type(request.arg)=='string' and #request.arg<=64 and not request.arg:find('[%c]')then id,name=resolvePlayer(request.arg)end
        if not id or id==app.game.sample.playerId then ok=false;errorText=errorText or (not id and name) or 'Choose another online player by name or ID.'
        else ok=app.server:startFind(id,name,true)end
    end
    if not ok then app.server.actionNotify(errorText or 'Action unavailable, already running or on cooldown.','error','quick-actions')end
end

local function diagnostics()
    print('[LuaHZ diagnostics] '..importSource)
    print('Font: '..tostring(app.im and app.im.FontSource or 'UI not initialized'))
    print('Horizon server detected: '..tostring(app.server.horizon))
    print('Player ready: '..tostring(app.game.sample.ready)..'; focused: '..tostring(app.focused))
    print('Horizon version: '..tostring(app.observations.observedVersion or 'unknown')..'; '..app.observations:versionStatus())
    print('Command capture: '..tostring(app.observations.active==true)..'; file='..tostring(app.observations.path))
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
    register('luahzactions',toggleActions)
    register('luahzvehicle',toggleVehicle)
    register('hbdebug',diagnostics)
    register('hbreload',function() app.reloadRequested=true end)
    register('luahzdebug',diagnostics)
    register('luahzreload',function() app.reloadRequested=true end)
    register('luahzcapture',function(arg)guard('Observations',function()captureAction((arg or ''):lower():match('^%s*(.-)%s*$'))end)end)
    register('luahzversion',function()
        notify('Observed Horizon version: '..tostring(app.observations.observedVersion or 'unknown')..'. '..app.observations:versionStatus())
    end)
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
            app.server:stopFind();notify('Autofind stopped.');return
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
    for _,name in ipairs({'onPlayAudioStream','onStopAudioStream','onServerMessage','onSendCommand','onApplyPlayerAnimation','onClearPlayerAnimation','onShowDialog','onSendDialogResponse','onCreateGangZone','onGangZoneDestroy','onGangZoneFlash','onGangZoneStopFlash','onSetMapIcon','onRemoveMapIcon','onSetCheckpoint','onDisableCheckpoint','onSetRaceCheckpoint','onDisableRaceCheckpoint','onShowTextDraw','onTextDrawSetString','onTextDrawHide','onGamemodeRestart','onPlayerQuit','onPlayerJoin'}) do previous[name]=events[name] end
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
        guard('Observations',function()app.observations:event('chat',{text=text})end)
        local vehicleOk,vehicleHide=guard('Vehicle',function()return app.vehicle:onMessage(text,app.server.characterName)end)
        local success,hide=guard('Server',function() return app.server:onMessage(text) end)
        if vehicleOk and vehicleHide or success and hide then return false end
    end
    function events.onSendCommand(command)
        guard('Observations',function()app.observations:onOutgoing(command)end)
        guard('Vehicle',function()app.vehicle:onOutgoing(command)end)
        guard('Server',function() app.server:onOutgoing(command) end)
    end
    function events.onApplyPlayerAnimation(playerId,animLib,animName)
        guard('Game',function()app.game.reloadGuard:onAnimation(playerId,animName)end)
    end
    function events.onClearPlayerAnimation(playerId)
        guard('Game',function()app.game.reloadGuard:onClear(playerId)end)
    end
    function events.onShowDialog(id,style,title,_,_,text)
        if app.vehicleUI then app.vehicleUI:reset()end
        guard('Observations',function()app.observations:dialog(id,style,title,text)end)
        local success,hide=guard('Server',function() return app.server:onDialog(id,title,text,style) end)
        if success and hide then return false end
    end
    function events.onSendDialogResponse(id,button,list,input)
        guard('Observations',function()app.observations:dialogResponse(id,button,list)end)
        guard('Server',function() app.server:onDialogResponse(id,button,list,input) end)
    end
    function events.onCreateGangZone(id,startPos,endPos,color) app.server.zones[id]={min=startPos,max=endPos,color=color} end
    function events.onGangZoneDestroy(id) app.server.zones[id]=nil end
    function events.onGangZoneFlash(id,color) if app.server.zones[id] then app.server.zones[id].flashColor=color end end
    function events.onGangZoneStopFlash(id) if app.server.zones[id] then app.server.zones[id].flashColor=nil end end
    function events.onSetMapIcon(id,position,kind,color,style)
        guard('Observations',function()app.observations:event('map_icon',{id=id,x=position.x,y=position.y,z=position.z,kind=kind,color=color,style=style})end)
        app.server:onMapIcon(id,position,kind,color,style)
    end
    function events.onRemoveMapIcon(id)
        guard('Observations',function()app.observations:event('remove_map_icon',{id=id})end)
        app.server:removeMapIcon(id)
    end
    function events.onSetCheckpoint(position)
        guard('Observations',function()app.observations:event('checkpoint',{x=position.x,y=position.y,z=position.z})end)
        app.server.checkpoint=position
    end
    function events.onDisableCheckpoint()
        guard('Observations',function()app.observations:event('disable_checkpoint')end)
        app.server.checkpoint=nil
    end
    function events.onSetRaceCheckpoint(kind,position,nextPosition,size)
        guard('Observations',function()
            app.observations:event('race_checkpoint',{kind=kind,x=position.x,y=position.y,z=position.z,
                next_x=nextPosition.x,next_y=nextPosition.y,next_z=nextPosition.z,size=size})
        end)
    end
    function events.onDisableRaceCheckpoint()
        guard('Observations',function()app.observations:event('disable_race_checkpoint')end)
    end
    function events.onShowTextDraw(id,td)
        guard('Observations',function()
            app.observations:observeTextdraw(id,td.text,'login textdraw event')
            app.observations:event('textdraw',{id=id,text=td.text or ''})
        end)
        app.server:onTextdraw(id,td.text or '')
        if app.overlay then
            local ok,result=guard('Native HUD',function() return app.overlay.serverHud:onShow(id,td,app.server.horizon) end)
            if ok then return result end
        end
    end
    function events.onTextDrawSetString(id,text)
        guard('Observations',function()
            app.observations:observeTextdraw(id,text,'textdraw update event');app.observations:event('textdraw_update',{id=id,text=text})
        end)
        app.server:onTextdraw(id,text)
    end
    function events.onTextDrawHide(id)
        guard('Observations',function()app.observations:hideTextdraw(id);app.observations:event('hide_textdraw',{id=id})end)
        app.server.textdraws[id]=nil;if app.overlay then app.overlay.serverHud.positions[id]=nil end
    end
    function events.onGamemodeRestart()
        app.captureRequest=nil
        app.observations:reset();app.vehicle:reset()
        if app.vehicleUI then app.vehicleUI:reset()end
        app.server:reset();app.server.horizon=true;app.game:cleanup()
        app.game.sample={ready=false,alive=false}
        if app.ui then app.ui.open[0]=false;app.ui.capture=nil;app.ui.previewMap=false end
        if app.status then app.status.open[0]=false end
        if app.overlay then app.overlay.mapOpen=false;app.overlay:restoreNative() end
        app.nativeLocations:cleanup()
    end
    function events.onPlayerQuit(id)
        if app.server.find.active and tostring(id)==app.server.find.id then
            app.server:dropNavigationQueue(true,false)
            app.server.find.paused=true;app.server.find.description='Target disconnected; waiting for rejoin.'
        end
    end
    function events.onPlayerJoin(id,color,isNpc,name)
        if app.server.find.active and Logic.normalizeName(name)==Logic.normalizeName(app.server.find.name) then
            app.server.find.id=tostring(id);app.server.find.paused=false;app.server.find.nextAt=getGameTimer()+3000
        end
    end
    for _,name in ipairs({'onPlayAudioStream','onStopAudioStream','onServerMessage','onSendCommand','onApplyPlayerAnimation','onClearPlayerAnimation','onShowDialog','onSendDialogResponse','onCreateGangZone','onGangZoneDestroy','onGangZoneFlash','onGangZoneStopFlash','onSetMapIcon','onRemoveMapIcon','onSetCheckpoint','onDisableCheckpoint','onSetRaceCheckpoint','onDisableRaceCheckpoint','onShowTextDraw','onTextDrawSetString','onTextDrawHide','onGamemodeRestart','onPlayerQuit','onPlayerJoin'}) do
        local handler=events[name]
        local wrapper=function(...)
            if sessionActive() then return handler(...) end
        end
        ownedEvents[name]={module=events,wrapper=wrapper,previous=previous[name]}
        events[name]=wrapper
    end
end

local function closePanels()
    if app.vehicleUI then app.vehicleUI:reset()end
    if app.vehicle then app.vehicle.pending=nil end
    if app.ui then
        app.ui.open[0]=false;app.ui.capture=nil;app.ui.previewMap=false;app.ui.infoNotice=nil
        if app.ui.horizonSearch then for _,buffer in pairs(app.ui.horizonSearch)do app.im.StrCopy(buffer,'')end end
    end
    if app.status then app.status.open[0]=false end
    if app.overlay then app.overlay.mapOpen=false;app.overlay.preview=false end
    if app.actions then app.actions:reset()end
    app.quickRequest=nil
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
    pcall(function()app.observations:reset()end)
    pcall(function()app.vehicle:reset()end)
    app.game.sample={ready=false,alive=false};app.game.ammoHistory={};app.game.lastAmmo=nil
    app.game.maxStamina=0;app.game.maxBreath=0
    app.audioHistory={};app.wasReady=false;app.commandBindDue=nil;app.saveDue=nil
    app.captureRequest=nil
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
    print('[LuaHZ] 0.4.0 authorized endpoint 213.32.6.232:7777; waiting for login.')
end

local function tick()
    if not sessionActive() then stop();return end
    if focusProvider then app.focused=focusProvider() end
        guard('Observations',function()
            if not app.focused then app.observations:stop('window lost focus') end
            app.observations:update()
        end)
        guard('Game',function()
            app.game:refresh();app.game.reloadGuard:update(app.game.sample,app.focused)
            hotkeys();app.game:drive(blocked(true,true))
        end)
        guard('Vehicle',function()app.vehicle:update(app.game.sample,app.focused and not isPauseMenuActive())end)
        if app.vehicleUI then
            app.vehicleUI.cursor=app.vehicleUI.open[0] and app.focused and not isTyping() and not isPauseMenuActive() and Keys.modifiers()==4
            app.vehicleFrame.HideCursor=not app.vehicleUI.cursor
        end
        if app.vehicleUI and (not app.game.sample.ready or not app.game.sample.alive)then app.vehicleUI:reset();app.quickRequest=nil end
        if app.observations.active and app.observations.mode=='vehicles' then
            guard('Observations',function()
                local s=app.game.sample
                app.observations:vehicleContext({vehicle=s.vehicle,model=s.model,driver=s.driver,
                    vehicleName=s.vehicleName,lockState=s.lockState,
                    networkId=s.vehicle and Game.call('sampGetVehicleIdByCarHandle',-1,s.vehicle) or -1})
            end)
        end
        if app.actions and (not app.game.sample.ready or not app.game.sample.alive)then app.actions:reset();app.quickRequest=nil end
        if not app.game.sample.ready then
            if app.wasReady and Game.call('sampGetGamestate',5)~=3 then
                app.server:reset();app.server.horizon=true
                app.observations:reset();app.vehicle:reset()
                if app.vehicleUI then app.vehicleUI:reset()end
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
        guard('Quick Actions',executeQuickAction)
        guard('Observations',function()
            local request=app.captureRequest
            if not request then return end
            local now=getGameTimer()
            if not app.observations.active then app.captureRequest=nil;return end
            if now>=request.expires or not app.server.loginSeen then
                app.captureRequest=nil;app.observations:stop('request expired before sending');return
            end
            if not blocked() and app.server.ready and now-app.server.lastSend>=1200 then
                app.captureRequest=nil
                app.observations:onOutgoing(request.command,'explicit read-only capture')
                if not app.observations.active or not app.observations.window then return end
                app.server:onOutgoing(request.command,false) -- Explicit diagnostic captures retain normal chat output.
                local ok,err=pcall(sampSendChat,request.command)
                if not ok then app.observations:stop('send failure');error(err) end
                app.server.lastSend=now
            end
        end)
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
        guard('Server',function() app.server:update(function(command)
            if app.server.commandSequence then
                guard('Observations',function()app.observations:onOutgoing(command,'keybind sequence')end)
            elseif app.server.clearNavigation and command=='/killcheckpoint' then
                guard('Observations',function()app.observations:onOutgoing(command,'quick-actions')end)
            end
            sampSendChat(command)
        end,sampSendDialogResponse,not (app.observations.single and app.observations.window) and not isTyping() and not isPauseMenuActive() and
            not (app.ui and app.ui.open[0]) and not (app.actions and app.actions.open[0] and not app.server.statsRequested) and not(app.vehicleUI and app.vehicleUI.open[0]) and not (app.overlay and app.overlay.mapOpen),
            app.server.loginSeen and app.focused and not isTyping() and not isPauseMenuActive() and
            not (app.overlay and app.overlay.mapOpen) and not (app.status and app.status.open[0] and not(app.server.infoRequested and app.server.infoRequested.kind=='licenses')) and not(app.actions and app.actions.open[0]) and not(app.vehicleUI and app.vehicleUI.open[0]),
            app.server.loginSeen and not blocked(false,true)) end)
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

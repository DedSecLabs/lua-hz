package.path='src/lib/?.lua;src/lib/?/init.lua;'..package.path
local Config=require 'horizonbase.config'
local Logic=require 'horizonbase.logic'
local Server=require 'horizonbase.server'
local Game=require 'horizonbase.game'
local passed=0
local function test(name,fn)
    local ok,err=pcall(fn)
    if not ok then error(name..': '..tostring(err)) end
    passed=passed+1;print('PASS '..name)
end
local function eq(actual,expected) assert(actual==expected,tostring(actual)..' ~= '..tostring(expected)) end

test('INI migration accepts CRLF, preserves false and ignores unknown fields',function()
    local c=Config.validate(Config.parse('[togs]\r\nrepair=false\r\nrepairMax=17\r\n[settings]\r\nstamina=false\r\nlastSeenVersion=0.14.4\r\n'))
    eq(c.togs.repair,false);eq(c.togs.repairMax,17);eq(c.settings.stamina,false);eq(c.settings.lastSeenVersion,nil)
end)
test('Malformed numbers and wrong types use validated bounds',function()
    local c=Config.validate({settings={badge='true',vdb=100},quickmap={opacity=-5},keybinds={settingsPanel=999},fps={onfoot=4,invehicle=math.huge}})
    eq(c.settings.badge,nil);eq(c.settings.vdb,2);eq(c.quickmap.opacity,0);eq(c.keybinds.settingsPanel,255);eq(c.fps.onfoot,20);eq(c.fps.invehicle,0)
end)
test('Preferences round trip without losing default options',function()
    local c=Config.copy(Config.defaults);c.togs.drugs=true;c.cruisecontrol.preset2Speed=91
    local result=Config.validate(Config.parse(Config.serialize(c)))
    eq(result.togs.drugs,true);eq(result.cruisecontrol.preset2Speed,91);eq(result.keybinds.settingsPanel,120)
end)
test('Old preferences gain size and position settings without losing keybinds',function()
    local c=Config.validate({keybinds={quickmap=77},settings={stamina=false}})
    eq(c.interface.scale,100);eq(c.hud.x,100);eq(c.hud.y,5);eq(c.settings.stamina,false)
    local round=Config.validate(Config.parse(Config.serialize(c)))
    eq(round.hud.scale,100);eq(round.keybinds.quickmap,77)
end)
test('UI and HUD preferences clamp invalid sizes and positions',function()
    local c=Config.validate({interface={scale=999},hud={scale=2,x=-50,y=400}})
    eq(c.interface.scale,200);eq(c.hud.scale,50);eq(c.hud.x,0);eq(c.hud.y,100)
end)
test('High-resolution UI grows and remains inside the viewport',function()
    local scale=Logic.interfaceScale(2560,1440,100)
    assert(scale>1.3 and scale<1.4)
    scale=Logic.interfaceScale(1280,720,200)
    assert(660*scale<=1248 and 540*scale<=688)
end)
test('HUD edge positions cannot place the panel outside the screen',function()
    for _,x in ipairs({0,50,100}) do
        for _,y in ipairs({0,50,100}) do
            local layout=Logic.hudLayout(1920,1080,{scale=200,x=x,y=y},292)
            assert(layout.x>=0 and layout.y>=0)
            assert(layout.x+layout.width<=1920 and layout.y+layout.height<=1080)
        end
    end
end)
test('Horizon protected health decodes to the actual player health',function()
    eq(Logic.displayHealth(5000090,true),90)
    eq(Logic.displayHealth(5000000,true),0)
    eq(Logic.displayHealth(90,false),90)
    eq(Logic.displayHealth(5000090,false),5000090)
end)
test('Magazine label does not show the large engine reserve as clip ammunition',function()
    eq(Logic.ammoLabel(17),'Magazine: 17');eq(Logic.ammoLabel(0),'Magazine: 0')
    eq(Logic.ammoLabel(nil),'Magazine: --')
end)
test('Native weapon state reads the current clip separately from total ammo',function()
    local pointer,slot=0x10000,2
    local weapon=pointer+0x5A0+slot*0x1C
    local clip=17
    local oldPointer=_G.getCharPointer;_G.getCharPointer=function()return pointer end
    local oldMemory=package.loaded.memory
    package.loaded.memory={getfloat=function(address)assert(address==pointer+0x540);return 5000090 end,
        getuint8=function(address)assert(address==pointer+0x718);return slot end,
        getuint32=function(address)
            if address==weapon then return 22 end
            if address==weapon+8 then return clip end
            if address==weapon+12 then return 60000 end
            error('Unexpected native read')
        end}
    local g=Game.new(Config.copy(Config.defaults),function()end);g.sample={weapon=22}
    g:readNativeState(1);eq(g.sample.rawHealth,5000090);eq(g.sample.ammoClip,17);eq(g.sample.ammoTotal,60000)
    clip=16;g:readNativeState(1);eq(g.sample.ammoClip,16)
    package.loaded.memory=oldMemory;_G.getCharPointer=oldPointer
end)
test('Repair offer enforces price cap and strip colors',function()
    local offer=Logic.offer('{FFFFFF}John wants to repair your car for $1, (type /accept repair)')
    eq(offer.kind,'repair');eq(offer.price,1)
    local c=Config.copy(Config.defaults).togs
    eq(Logic.allowOffer(offer,c),false);c.repair=true;eq(Logic.allowOffer(offer,c),true)
    offer.price=2;eq(Logic.allowOffer(offer,c),false)
end)
test('Defense, sex and drug offers preserve actual accept command',function()
    eq(Logic.offer('John wants to defend you for $200, (type /accept defense)').command,'/accept defense')
    eq(Logic.offer('John is offering you to have sex with them, for $1 (type /accept sex)').kind,'whore')
    local d=Logic.offer('John wants to sell you 2 gram(s) for $1, (type /accept pot)')
    eq(d.kind,'drugs');eq(d.command,'/accept pot')
    eq(Logic.offer('John wants to sell you 2 gram(s) for $1, with no command'),nil)
end)
test('Ambiguous messages are not offers',function()
    eq(Logic.offer('You repaired your car for $500.'),nil)
    eq(Logic.offer('John wants to repair your car for free.'),nil)
end)
test('Taxi call has no fabricated price',function()
    local offer=Logic.offer('John is in need of a taxi driver at El Corona.')
    eq(offer.kind,'taxi');eq(offer.price,nil)
end)
test('Map coordinates match the actual tile orientation',function()
    local x,y=Logic.worldToMap(-3000,3000,10,20,600);eq(x,10);eq(y,20)
    x,y=Logic.worldToMap(3000,-3000,10,20,600);eq(x,610);eq(y,620)
    x,y=Logic.worldToMap(0,0,10,20,600);eq(x,310);eq(y,320)
end)
test('FPS contexts choose swimming before vehicle and boat before car',function()
    eq(Logic.context({swimming=true,vehicle=123}),'swimming');eq(Logic.context({vehicle=123,boat=true}),'inboat')
    eq(Logic.context({vehicle=123}),'invehicle');eq(Logic.context({}),'onfoot')
end)
test('Cruise throttle uses accelerator only and has bounded output',function()
    eq(Logic.cruiseThrottle(51,50),0);eq(Logic.cruiseThrottle(0,50),255)
    assert(Logic.cruiseThrottle(49,50)>0)
end)
test('Conditional numeric getters use the output, not the boolean status',function()
    _G.testConditionalGetter=function()return true,2 end
    eq(Game.call('testConditionalGetter',0),2)
    _G.testConditionalGetter=function()return false,0 end
    eq(Game.call('testConditionalGetter',0),0)
    _G.testConditionalGetter=nil
end)
test('Numeric getters reject booleans and invalid outputs without breaking HUD',function()
    _G.testConditionalGetter=function()return true end
    eq(Game.call('testConditionalGetter',0),0)
    _G.testConditionalGetter=function()return true,'not a level' end
    eq(Game.call('testConditionalGetter',0),0)
    _G.testConditionalGetter=function()return true,0/0 end
    eq(Game.call('testConditionalGetter',0),0)
    _G.testConditionalGetter=nil
end)
test('Predicates retain boolean return values',function()
    _G.testPredicate=function()return false end
    eq(Game.call('testPredicate',true),false)
    _G.testPredicate=function()return true end
    eq(Game.call('testPredicate',false),true)
    _G.testPredicate=nil
end)

local function fixture()
    local time=0;local sent={};local c=Config.copy(Config.defaults)
    local server=Server.new(c,function() end,function() return time end)
    server.ready=true;server.horizon=true
    local function update() server:update(function(command) sent[#sent+1]=command end,function() end) end
    return server,c,sent,function(n) time=n end,update
end
test('Offer acceptance waits, deduplicates and obeys Horizon context',function()
    local s,c,sent,clock,update=fixture();c.togs.repair=true
    s:onMessage('John wants to repair your car for $1, (type /accept repair)')
    s:onMessage('John wants to repair your car for $1, (type /accept repair)')
    update();eq(#sent,0);clock(500);update();eq(#sent,1);eq(sent[1],'/accept repair')
    s.horizon=false;clock(5000);s:onMessage('John wants to repair your car for $1, (type /accept repair)');update();eq(#sent,1)
end)
test('Leaving the game drops queued actions',function()
    local s,c,sent,clock,update=fixture();c.togs.repair=true
    s:onMessage('John wants to repair your car for $1, (type /accept repair)');s.ready=false
    clock(500);update();eq(#sent,0);eq(#s.queue,0)
end)
test('Stopping autofind prevents a queued find from being sent',function()
    local s,c,sent,clock,update=fixture();s.lastSend=0
    s:startFind(17,'John_Doe');update();s.find.active=false;clock(2000);update();eq(#sent,0)
end)
test('Only the intended detective target triggers a cohort lookup',function()
    local s,c,sent,clock,update=fixture();c.autofind.cohort=true;s:startFind(17,'John_Doe')
    s:onMessage('Other_Person has been last seen at Los Santos.');eq(#s.queue,0)
    s:onMessage('John Doe has been last seen at El Corona.');eq(s.find.description,'El Corona');eq(s.queue[1].command,'/cohort 17')
end)
test('Vehicle dialog refresh replays only the explicit prior selection',function()
    local s=fixture();s:toggleTrack();s:onOutgoing('/trackcar');eq(s:onDialog(50,'Vehicle Tracker','Vehicle #1\nVehicle #2\nVehicle #3',2),false)
    s:onDialogResponse(50,1,2,'Vehicle #3');s.track.refresh=true;s:onOutgoing('/trackcar')
    eq(s:onDialog(51,'Unrelated dialog'),false);eq(s.track.response,nil);eq(s.track.active,false)
    s.track.active=true;s.track.refresh=true;s:onOutgoing('/trackcar')
    eq(s:onDialog(52,'Vehicle Tracker','Vehicle #3\nVehicle #1\nVehicle #2',2),true);eq(s.track.response.list,0)
end)
test('Turning off acceptance cancels a queued offer',function()
    local s,c,sent,clock,update=fixture();c.togs.repair=true
    s:onMessage('John wants to repair your car for $1, (type /accept repair)');c.togs.repair=false
    clock(500);update();eq(#sent,0)
end)
test('Offer expiry prevents accepting an obsolete server offer',function()
    local s,c,sent,clock,update=fixture();c.togs.repair=true
    s:onMessage('John wants to repair your car for $1, (type /accept repair)')
    clock(7000);update();eq(#sent,0)
end)
test('Vehicle tracker waits for selection without repeatedly opening dialogs',function()
    local s,c,sent,clock,update=fixture();s:toggleTrack();update();eq(#sent,1)
    clock(20000);update();eq(#sent,1)
end)
test('Detective job rejection stops automated location queries',function()
    local s,c,sent,clock,update=fixture();s:startFind(17,'John_Doe');s:onMessage('You are not a detective.')
    clock(2000);update();eq(#sent,0);eq(s.find.active,false)
end)
test('Reload animation request is server-scoped and respects ready/alive/on-foot state',function()
    local g=Game.new(Config.copy(Config.defaults),function()end)
    g.server={horizon=true};g.sample={ready=true,alive=true,vehicle=false,weapon=22}
    eq(g:reload(),'/reload 2')
    for weapon=0,46 do
        g.sample.weapon=weapon
        eq(g:reload(),weapon>=22 and weapon<=34 and '/reload 2' or nil)
    end
    g.sample.weapon=22
    g.sample.vehicle=1;eq(g:reload(),nil)
    g.sample.vehicle=false;g.sample.alive=false;eq(g:reload(),nil)
    g.sample.alive=true;g.sample.ready=false;eq(g:reload(),nil)
    g.sample.ready=true;g.server.horizon=false;eq(g:reload(),nil)
end)
print(('Passed %d core tests'):format(passed))


test('Native GTA clock validates both returned time fields',function()
    local old=_G.getTimeOfDay
    local oldMemory=package.loaded.memory;package.loaded.memory={}
    local oldPed=_G.PLAYER_PED
    _G.getTimeOfDay=function()return 22,56 end
    local g=Game.new(Config.copy(Config.defaults),function()end)
    -- These stubs are local to this test; the native time pair is observed, not set.
    local names={'doesCharExist','isSampAvailable','sampGetGamestate','isCharDead','getCharCoordinates','getCharPointer','getCharModel','sampGetPlayerIdByCharHandle'}
    local previous={}
    for _,name in ipairs(names)do previous[name]=_G[name]end
    _G.PLAYER_PED=1
    _G.doesCharExist=function()return true end;_G.isSampAvailable=function()return true end
    _G.sampGetGamestate=function()return 3 end;_G.isCharDead=function()return false end
    _G.getCharCoordinates=function()return 0,0,0 end;_G.getCharPointer=function()return 0 end
    _G.getCharModel=function()return true,292 end;_G.sampGetPlayerIdByCharHandle=function()return true,17 end
    g:refresh();eq(g.sample.hour,22);eq(g.sample.minute,56);eq(g.sample.skin,292);eq(g.sample.playerId,17)
    _G.getCharModel=function()return 0 end;g:refresh();eq(g.sample.skin,0)
    _G.getCharModel=function()return 20001 end;g:refresh();eq(g.sample.skin,nil)
    _G.getTimeOfDay=function()return 99,math.huge end
    g:refresh();eq(g.sample.hour,nil);eq(g.sample.minute,nil)
    _G.getTimeOfDay=old;package.loaded.memory=oldMemory;_G.PLAYER_PED=oldPed
    for _,name in ipairs(names)do _G[name]=previous[name]end
end)


test('Vehicle lock state is observed from the existing getter',function()
    local old=_G.getCarDoorLockStatus
    _G.getCarDoorLockStatus=function(handle)eq(handle,99);return 2 end
    eq(Game.call('getCarDoorLockStatus',-1,99),2)
    _G.getCarDoorLockStatus=function()return true,1 end
    eq(Game.call('getCarDoorLockStatus',-1,99),1)
    _G.getCarDoorLockStatus=function()return nil end
    eq(Game.call('getCarDoorLockStatus',-1,99),-1)
    _G.getCarDoorLockStatus=old
end)

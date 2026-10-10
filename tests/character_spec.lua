package.path='tests/?.lua;src/lib/?.lua;'..package.path
local Character=require 'horizonbase.character'
local Server=require 'horizonbase.server'
local Config=require 'horizonbase.config'
local clock=0
local function now()return clock end
local lines={
    '{FFFFFF}John Doe - (Level: 1) - (Playing hours: 7) - (Gender: Male) - (Age: 35) - (Phone number: 945674) - (Warnings: 0)',
    '(Faction: None) - (Rank: None [0]) - (Division: None) - (Job: None [lvl: 0]) - (Job 2: None [lvl: 0])',
    '(Total wealth: $5,708) - (Cash: $5,251) - (Bank balance: $457) - (Insurance: None) - (Married to: Nobody)',
    '(Respect points: 7/8 [$5,000]) - (Upgrades: 0) - (Spawn armor: 0.0) - (Health: 90.0) - (Armor: 0.0) - (Radio: 1 kHz)',
    '(Crimes: 0) - (Arrests: 0) - (Wanted Level: 0) - (Materials: 150) - (Pot: 0) - (Crack: 0) - (Packages: 0) - (Crates: 0)',
    '(Rope: 0) - (Cigars: 20) - (Sprunk: 1) - (Spray: 6) - (Seeds: 0) - (Blindfolds: 0) - (Ref Tokens: 0) - (Donator: No)'
}
local c=Character.new(now)
c:ingest(lines[1],'John_Doe');assert(not c.updatedAt)
c:begin();c:ingest('(Cash: $999)','John_Doe');assert(not c.draft)
c:ingest(lines[1]:gsub('John Doe','Jane Doe'),'John_Doe');assert(not c.draft)
for _,line in ipairs(lines)do c:ingest(line,'John_Doe')end
assert(c.state=='ready' and c.name=='John Doe' and not c.partial)
assert(c.fields.Cash=='$5,251' and c.fields.Job=='None [lvl: 0]' and c.fields['Bank balance']=='$457')
assert(c.fields['Respect points']=='7/8 [$5,000]' and c.fields.Armor=='0.0' and c.fields.Donator=='No')
c:ingest('(Cash: $999)','John_Doe');assert(c.fields.Cash=='$5,251')
print('PASS own-character multi-line stats parsing, money/job preservation and unrelated chat isolation')
clock=10000;c:begin();c:ingest(table.concat(lines,'\n'),'John_Doe');assert(c.state=='ready')
c:begin();c:ingest(lines[1],'John_Doe');clock=11000;c:update();assert(c.partial and c.fields.Cash==nil)
c:begin();clock=24000;c:update();assert(c.error and c.state=='ready' and c.fields.Cash==nil)
c:reset();assert(c.name==nil and next(c.fields)==nil and not c.pending and not c.updatedAt)
print('PASS dialog-sized response, partial snapshot, timeout preserves last snapshot and reset clears character')
local s=Server.new(Config.copy(Config.defaults),function()end,now)
s.ready=true;s.horizon=true;s.characterName='John_Doe'
local sent={};local function send(command)sent[#sent+1]=command end
s:update(send,function()end,true);assert(#sent==0,'Server detection alone must not fetch before login')
s:onMessage('Welcome to Horizon Roleplay, John Doe.')
clock=clock+5001;s:update(send,function()end,false);assert(#sent==0,'Typing/dialog guard must defer request')
s:update(send,function()end,true);assert(#sent==1 and sent[1]=='/stats' and s.character.pending)
for _,line in ipairs(lines)do s:onMessage(line)end
assert(s.character.fields.Donator=='No')
s:onMessage('Welcome to Horizon Roleplay, John Doe.');clock=clock+10001
s:update(send,function()end,true);assert(#sent==1,'Welcome repeats must not poll')
assert(s:requestStats());assert(not s:requestStats());s:update(send,function()end,true);assert(#sent==2)
assert(not s:requestStats(),'Do not duplicate a request in flight')
s:onDialog(5,'Stats',table.concat(lines,'\n'),0);assert(s.character.fields.Cash=='$5,251')
clock=clock+10001;s:onOutgoing('/stats');assert(s.character.pending)
s:onMessage(lines[1]);s:onMessage(lines[6]);assert(s.character.fields.Donator=='No')
s:reset();assert(not s.loginSeen and s.character.name==nil and next(s.character.fields)==nil)
s.ready=true;s.characterName='John_Doe';s:update(send,function()end,true);assert(#sent==2)
print('PASS one request after login, guarded sending, manual refresh/command capture, no polling and reconnect reset')
local im=require 'fake_imgui'
function getScreenResolution()return 1920,1080 end
function getGameTimer()return clock end
local prefs=Config.copy(Config.defaults)
package.preload.vkeys=function()return {id_to_name=function()return 'I'end}end
local ui=require('horizonbase.ui').new(im,prefs,function()end,function()end)
local panel=require('horizonbase.character_ui').new(im,ui,s)
panel:draw();assert(im.stack==0)
s.horizon=true;s.ready=true;s.characterName='John_Doe';s.character:begin()
for _,line in ipairs(lines)do s:onMessage(line)end
panel:draw();assert(im.stack==0)
clock=clock+10001;im.clicks.Refresh=true;panel:draw();assert(s.statsRequested)
im.clicks['##closeCharacter']=true;panel:draw();assert(not panel.open[0])
assert(prefs.keybinds.characterStatus==73 and prefs.modifiers.characterStatus==0)
assert(Config.keyConflict(prefs,73)=='characterStatus')
local round=Config.validate(Config.parse(Config.serialize(prefs)));assert(round.keybinds.characterStatus==73)
print('PASS status panel empty/populated states, refresh/close, configurable I and preference persistence')

local labels={};local oldDisabled=im.TextDisabled
im.TextDisabled=function(text)labels[text]=true;oldDisabled(text)end
local requests=0;local oldRequest=s.requestStats
s.requestStats=function()requests=requests+1 end
for i,tab in ipairs({'Character','Work','Finances','Health','Inventory'})do
    labels={};im.clicks[tab..'##characterTab'..i]=true;panel:draw()
    assert(panel.tab==i and im.stack==0)
    for j,group in ipairs(Character.groups)do
        for _,label in ipairs(group[2])do
            assert((labels[label]==true)==(i==j),'Only selected section fields should be visible: '..label)
        end
    end
end
assert(requests==0,'Changing tabs must not send server commands')
s.requestStats=oldRequest;im.TextDisabled=oldDisabled;panel.tab=1
print('PASS all five character sections accessible independently without extra stats requests')

local Live=require 'horizonbase.character_live'
local live={ready=true,skin=292,playerId=0,health=76,armour=54,money=1234567}
assert(Live.value('Cash',live)=='$1,234,567' and Live.value('Health',live)=='76' and Live.value('Armor',live)=='54')
assert(Live.value('Bank balance',live)==nil and Live.value('Wanted Level',live)==nil and Live.value('Level',live)==nil,
    'Native data must not invent RPG account fields or equate scoreboard score with level')
live.money=-500;assert(Live.value('Cash',live)=='-$500')
local pictures={};local originalDraw=im.GetWindowDrawList
local draw=originalDraw();local oldImage=draw.AddImage
draw.AddImage=function(_,tex,a,b)pictures[#pictures+1]={tex=tex,a=a,b=b}end
local portraitPaths={}
ui.overlay={game={sample=live},texture=function(_,path)portraitPaths[#portraitPaths+1]=path;return 42 end}
for _,screen in ipairs({{1920,1080},{1280,720},{640,480},{320,480}})do
    function getScreenResolution()return screen[1],screen[2]end
    for _,scale in ipairs({80,100,200})do
        prefs.interface.scale=scale;pictures={};portraitPaths={};panel:draw()
        assert(im.stack==0 and portraitPaths[#portraitPaths]=='portraits-v0222/292.png')
        local image=pictures[#pictures]
        assert(math.abs((image.b.x-image.a.x)/(image.b.y-image.a.y)-165/300)<.001,'Portrait aspect ratio must be preserved')
    end
end
live.skin=0;portraitPaths={};panel:draw();assert(portraitPaths[#portraitPaths]=='portraits-v0222/0.png','CJ skin zero is valid')
live.skin=74;portraitPaths={};panel:draw();assert(#portraitPaths==1,'Unknown skin must not select a different portrait')
live.ready=false;assert(Live.value('Cash',live)==nil);portraitPaths={};panel:draw();assert(#portraitPaths==1,'Disconnected ped data must not select an avatar')
draw.AddImage=oldImage;im.GetWindowDrawList=originalDraw;ui.overlay=nil
function getScreenResolution()return 1920,1080 end
print('PASS live client fields, RPG source boundaries, current-skin portrait/aspect/scale, valid zero and unknown/disconnected fallback')

local migrated=Config.validate({custombinds={{name='Existing',command='/inventory',key=73}}})
assert(migrated.keybinds.characterStatus==0 and migrated.custombinds[1].key==73)
print('PASS new I default does not steal existing shortcuts during migration')

s:reset();s.horizon=true;s.ready=true;s.characterName='John_Doe'
s:onMessage('Welcome to Horizon Roleplay, John Doe.');clock=clock+5001
s.ready=false;s:update(send,function()end,true);local before=#sent
s.ready=true;s:update(send,function()end,false);assert(#sent==before)
s:update(send,function()end,true);assert(#sent==before+1)
clock=clock+13000;s:update(send,function()end,true);assert(#sent==before+1 and s.character.error)
print('PASS login fetch waits for ready/input guards and does not retry repeatedly after a timeout')

-- Silent mode is scoped to a LuaHZ-owned request, with exact stats framing.
local sep=string.rep('_',99)
c:reset();c:begin(true)
assert(not c:ingest('Advertisement: Cash: $99', 'John_Doe'))
assert(c:ingest(sep,'John_Doe'))
assert(c:ingest('', 'John_Doe'))
for _,line in ipairs(lines)do assert(c:ingest(line,'John_Doe'),line)end
assert(c.state=='ready' and c.fields.Cash=='$5,251')
assert(c:ingest(sep,'John_Doe'))
assert(not c:ingest(sep,'John_Doe'),'Only the one closing frame is suppressed')
assert(not c:ingest(lines[1],'John_Doe'),'Filter ends with the owned response')
c:begin(false)
assert(not c:ingest(sep,'John_Doe'))
for _,line in ipairs(lines)do assert(not c:ingest(line,'John_Doe'))end
assert(not c:ingest(sep,'John_Doe'))
print('PASS owned silent stats includes separators, preserves parsed data and leaves manual stats visible')
c:reset();c:begin()
c:ingest('John Doe - (Level: 1) - (Playing hours: 7) - (Gender: Male) - (Age: 35) - (Phone number: 1) - (Warnings: 0)','John_Doe')
c:ingest('(Crimes: 22) - (Arrests: 33) - (Wanted Level: 0) - (Materials: 86,401) - (Pot: 128) - (Crack: 120) - (Packages: 0) - (Crat','John_Doe')
assert(c.draft.fields.Crimes=='22' and c.draft.fields.Arrests=='33' and c.draft.fields['Wanted Level']=='0')
assert(c.draft.fields.Materials=='86,401' and c.draft.fields.Crates==nil)
assert(not c:ingest('(Cash: $999) Advertisement: unrelated','John_Doe') and c.draft.fields.Cash==nil)
print('PASS a chat-split /stats line keeps Crimes, Arrests and Wanted Level')
c:reset();c:begin()
c:ingest('Cosmin Young - (Level: 30) - (Playing hours: 1684) - (Gender: Male) - (Age: 34) - (Phone number: 498) - (Warnings: 0)','Cosmin_Young')
c:ingest('(Family: Magnolia Vigilance Protection) - (Rank: MVP Director [6]) - (Crew: Chief) - (Job: Detective [lvl: 5]) - (Job 2: Car Me','Cosmin_Young')
c:ingest('(Crimes: 226) - (Arrests: 33) - (Wanted Level: 0) - (Materials: 58,401) - (Pot: 125) - (Crack: 120) - (Packages: 0) - (Crates: ','Cosmin_Young')
assert(c.draft.fields.Faction=='Magnolia Vigilance Protection' and c.draft.fields.Rank=='MVP Director [6]')
assert(c.draft.fields.Division=='Chief' and c.draft.fields.Job=='Detective [lvl: 5]' and c.draft.fields['Job 2']==nil)
assert(c.draft.fields.Crimes=='226' and c.draft.fields.Arrests=='33' and c.draft.fields['Wanted Level']=='0')
assert(c.draft.fields.Crates==nil)
print('PASS the captured Horizon lines keep work, crimes, arrests and wanted level')
c:reset();c:begin()
for _,line in ipairs(lines)do c:ingest(line,'John_Doe')end
assert(c.fields.Materials=='150' and c.fields.Lockpicks==nil)
c:begin(false,true)
for _,line in ipairs({
    'Inventory:',
    '(Screwdriver: 2)',
    '(Wristwatch: 1) - (Tire: 1)',
    '(Firstaid: 57) - (Receiver: 1)',
    '(GPS: 1) - (Bug Sweep: 0)',
    '(Lockpicks: 2)'
}) do c:ingest(line,'John_Doe') end
clock=clock+750;c:update()
assert(c.fields.Lockpicks=='2' and c.fields.Screwdriver=='2' and c.fields['Bug Sweep']=='0')
assert(c.fields.Materials=='150' and c.fields.Level=='1','Inventory must not erase the /stats snapshot')
print('PASS /inv fields merge into Inventory and preserve /stats')
c:begin(true);assert(not c:ingest(lines[1]:gsub('John Doe','Jane Doe'),'John_Doe'))
assert(not c:ingest(sep,'John_Doe'))
c:begin(true);assert(c:ingest(lines[1],'John_Doe'))
assert(not c:ingest('(Cash: $999) Advertisement: unrelated', 'John_Doe'))
assert(not c:ingest('(Unknown field: value)', 'John_Doe'))
assert(c.draft.fields.Cash==nil,'Unrelated mixed text must not update the snapshot')
clock=clock+13000;c:update();assert(not c:ingest(sep,'John_Doe'))
c:begin(true);c:reset();assert(not c:ingest(sep,'John_Doe'))
print('PASS quiet mode does not hide foreign/unrecognized messages, expired responses or post-reset chat')
s:reset();s.horizon=true;s.ready=true;s.characterName='John_Doe';assert(s:requestStats())
s:update(function(command)
    assert(command=='/stats');s:onOutgoing(command) -- The real send invokes the outgoing RPC callback synchronously.
end,function()end,true)
assert(s.character.quiet and s:onMessage(lines[1]))
s:onOutgoing('/stats') -- A manual request takes over any automatic request already in flight.
assert(not s.character.quiet)
for _,line in ipairs(lines)do assert(not s:onMessage(line))end
print('PASS outgoing callback preserves owned silence and a manual request restores visible output')
s:reset();s.horizon=true;s.ready=true;s.characterName='John_Doe'
s:onMessage('Welcome to Horizon Roleplay, John Doe.')
clock=clock+5001;s:update(send,function()end,true);assert(sent[#sent]=='/stats')
for _,line in ipairs(lines)do s:onMessage(line)end
clock=clock+1500;s:update(send,function()end,true)
clock=clock+1500;s:update(send,function()end,true)
assert(sent[#sent]=='/inv','A completed stats snapshot requests inventory once')
print('PASS a completed /stats snapshot requests /inv once')

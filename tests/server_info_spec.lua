package.path='src/lib/?.lua;'..package.path
local Info=require 'horizonbase.server_info'
local now=0;local m=Info.new(function()return now end)
m:begin('families');m:onMessage('Gangs:')
for i=1,12 do m:onMessage(('* %d. {ABCDEF}Test Family %d{BBBBBB} | Leader: {FFFFFF}Leader Test %d{BBBBBB} | Members: {FFFFFF}120{BBBBBB} | Online: {FFFFFF}4'):format(i,i,i))end
m:onMessage('** (6) Family chat: ordinary message **')
now=8001;m:update();assert(#m.pages.families.rows==12 and not m.pages.families.partial)
assert(m.pages.families.rows[1].name=='Test Family 1' and m.pages.families.rows[12].id==12)
now=9000;m:begin('families');m:onMessage('Gangs:');m:onMessage('* 3. Sample | Leader: Person Test | Members: 10 | Online: 1')
now=17001;m:update();assert(m.pages.families.partial)
m:begin('families');now=25002;m:update();assert(#m.pages.families.rows==1 and m.pages.families.error,'Empty refresh must preserve the previous snapshot')
assert(not Info.family('* 1. Sample | Leader: Person Test | Members: 1 | Online: 3'))
print('PASS complete family rows, unrelated-chat exclusion, missing IDs and failed-refresh preservation')

m:onMessage('Members Online:')
m:onMessage('* Deputy Director {FFFFFF}Person With Middle Name{FFFFFF} (5) (Team Lead) {FFA500}')
m:onMessage('* Operative {FFFFFF}Another Person{FFFFFF} (1) (Newblood) {FFA500}')
now=33003;m:update();local member=m.pages.members.rows[2]
assert(member.name=='Person With Middle Name' and member.title=='Deputy Director' and member.rank==5 and member.label=='Team Lead')
assert(not Info.member('* Deputy Director Person Name (5) (Team Lead)'),'Do not guess uncolored title/name boundaries')
print('PASS colored title/name boundaries, middle names and family ranks rather than player IDs')

local settings={
    'Global Chat: {FF0606}Off{FFFFFF} | Newbie Chat: {00F70C}On{FFFFFF} | Speedo: Off | Toys: Off',
    'GPS: Off | Wristwatch: Off | CHUD: Off | VDB: Off',
    'Low HP Blink: Off | Turfs: Off | Damage Informer: Off',
    'Available commands: /toggc /tognewbie /speedo /wat /dat /gps /ww /chud /vdb /toghpblink /togturfs /dmginformer'}
for _,line in ipairs(settings)do m:onMessage(line)end
assert(not m.active and m.pages.settings.fields['Newbie Chat']=='On' and not m.pages.settings.partial)
assert(m.pages.settings.commands:find('/wat',1,true))
m:begin('settings');m:onMessage(settings[1]);now=42004;m:update();assert(m.pages.settings.partial and not m.pages.settings.fields.GPS)
m:onMessage('Website: {FFFFFF}hzgaming.net{FFA500} | Forums: {FFFFFF}forums.hzgaming.net')
m:onMessage('Discord: hzgaming.net/discord | Faction Discord: hzgaming.net/factiondiscord')
m:onMessage('Gang Discord: hzgaming.net/gangdiscord')
assert(not m.active and not m.pages.info.partial and m.pages.info.fields.Forums=='https://forums.hzgaming.net')
assert(not Info.safeLink('https://hzgaming.net.example.test/discord'))
assert(not Info.safeLink('javascript:example'))
assert(not Info.safeLink('hzgaming.net/discord\nstart'))
print('PASS complete/partial server settings, command list and strict community-link allowlist')

m:onMessage('*** Server Rules ***')
for _,name in ipairs({'Deathmatching (DM)','Revenge Killing (RK)','Non-RP Car Ramming','Gun Discharge Exploits','Powergaming/Metagaming (PG/MG)','Logging to Avoid','Exploiting','Robberies/Kidnapping','Hacking/Cheats'})do
    m:onMessage(name..' - Example rule text supplied by the server.')
end
m:onMessage('AdmCmd: unrelated event - must not become a rule')
m:onMessage('*** This is a short version of our server rulebook. Please visit hzgaming.net to see a full list of the server rules ***')
assert(not m.active and #m.pages.rules.rows==9 and not m.pages.rules.partial)
local c={fields={Level='2',['Respect points']='4'}}
m:onMessage('You need 10 more respect points to buy your next level.',c)
assert(m.respect.remaining==10);m:update(c);assert(m.respect)
c.fields['Respect points']='5';m:update(c);assert(not m.respect)
m:onMessage('You need 9 more respect points to buy your next level.',c);m:onCommand('/buylevel');assert(not m.respect)
m:reset();assert(not m.active and not m.respect and not m.pages.rules.updatedAt)
assert(not Info.kind('/buylevel') and not Info.kind('/gvl'))
print('PASS framed rules, passive respect response/invalidation and session cleanup')

local server=require('horizonbase.server').new(require('horizonbase.config').copy(require('horizonbase.config').defaults),function()end,function()return now end)
server.horizon=true;server.ready=true;server.loginSeen=true
assert(server:requestInfo('families'));assert(not server:requestInfo('members'))
local sent={};server:update(function(cmd)sent[#sent+1]=cmd end,function()end,false,true)
assert(#sent==1 and sent[1]=='/families','Refresh may run with settings UI open, without automatic stats fetching')
assert(not server:requestInfo('families'))
server:onMessage('Gangs:');server:onMessage('* 1. Test | Leader: Person Test | Members: 10 | Online: 1')
now=now+8001;server:update(function(cmd)sent[#sent+1]=cmd end,function()end,false,true)
assert(#server.info.pages.families.rows==1)
assert(not server:requestInfo('buylevel'))
server:reset();assert(not server.info.pages.families.updatedAt and not server.infoRequested)
print('PASS explicit read-only refresh scheduling, cooldown and endpoint reset')

now=100000;m=Info.new(function()return now end);m:begin('families',true)
assert(m:onMessage('Gangs:')==true)
assert(m:onMessage('* 1. Quiet Family | Leader: Person Test | Members: 10 | Online: 1')==true)
assert(m:onMessage('Newbie Person: ordinary conversation')==false)
assert(m:onMessage('Interest gained: $41')==false)
m:onCommand('/families',false)
assert(m:onMessage('Gangs:')==false,'Manual command must take over an owned quiet refresh')
assert(m:onMessage('* 1. Visible Family | Leader: Person Test | Members: 10 | Online: 1')==false)
m:reset();assert(m:onMessage('Gangs:')==false,'Passively recognized unsolicited headers remain visible')
for _,line in ipairs(settings)do assert(m:onMessage(line)==false)end
m:begin('settings',true)
for _,line in ipairs(settings)do assert(m:onMessage(line)==true,'Only exact owned settings rows should be suppressed')end
assert(m:onMessage('Website: hzgaming.net | Forums: forums.hzgaming.net')==false)
m:begin('info',true)
assert(m:onMessage('Website: hzgaming.net | Forums: forums.hzgaming.net')==true)
assert(m:onMessage('Discord: hzgaming.net/discord | Newbie: unrelated')==false)
m:begin('rules',true);assert(m:onMessage('*** Server Rules ***')==true)
assert(m:onMessage('Deathmatching (DM) - Example server rule.')==true)
assert(m:onMessage('AdmCmd: Person Test - unrelated announcement')==false)
assert(m:onMessage('*** This is a short version of our server rulebook. Please visit hzgaming.net to see a full list of the server rules ***')==true)
now=110000;server.horizon=true;server.ready=true;server.loginSeen=true
assert(server:requestInfo('members'))
server:update(function(command)server:onOutgoing(command)end,function()end,false,true)
assert(server:onMessage('Members Online:')==true)
assert(server:onMessage('* Operative {FFFFFF}Person Test{FFFFFF} (1) (Newblood) {FFA500}')==true)
assert(server:onMessage('A unrelated family conversation')==false)
server:onOutgoing('/members')
assert(server:onMessage('Members Online:')==false)
print('PASS owned-refresh silencing, normal chat/announcements, manual takeover, precise rows and sender reentrancy')

server:reset();server.horizon=true;server.ready=true;server.loginSeen=true;now=120000
assert(server:requestInfo('members'))
server:update(function(command)assert(command=='/members')end,function()end,false,true)
now=now+50;server:onOutgoing('/members')
assert(server:onMessage('Members Online:')==true,'Deferred owned echo must not turn Refresh into a manual command')
assert(server:onMessage('* Operative {FFFFFF}Person Test{FFFFFF} (1) (Newblood) {FFA500}')==true)
assert(not server.infoEcho,'Owned echo token must be consumed once')
server:onOutgoing('/members')
assert(server:onMessage('Members Online:')==false,'Later manual outgoing commands must remain visible')

server:reset();server.horizon=true;server.ready=true;server.loginSeen=true;now=130000
assert(server:requestInfo('members'))
server:update(function()end,function()end,false,true)
server:noteManualCommand('/members') -- Typed submission before any owned outgoing callback.
assert(not server.infoEcho)
server:onOutgoing('/members')
assert(server:onMessage('Members Online:')==false,'Manual Enter must revoke an unconsumed owned token')
assert(server:onMessage('* Operative {FFFFFF}Person Test{FFFFFF} (1) (Newblood) {FFA500}')==false)
server:reset();assert(not server.infoEcho)

server.horizon=true;server.ready=true;server.loginSeen=true;now=140000
assert(server:requestInfo('members'))
server:update(function()end,function()end,false,true)
server:onOutgoing('/members',false)
assert(server:onMessage('Members Online:')==false,'Explicit custom keybind must bypass owned echo matching')
server:reset();server.horizon=true;server.ready=true;server.loginSeen=true;now=150000
assert(server:requestInfo('members'))
assert(not pcall(function()server:update(function()error('Test send failure')end,function()end,false,true)end))
assert(not server.infoEcho and not server.info.active,'Failed send must discard ownership and the pending response')
server:reset();server.horizon=true;server.ready=true;server.loginSeen=true;now=160000
assert(server:requestInfo('members'));server:update(function()end,function()end,false,true)
now=161001;server:update(function()end,function()end,false,true)
assert(not server.infoEcho,'An absent outgoing callback must not leave an ownership token behind')
server:onOutgoing('/members');assert(server:onMessage('Members Online:')==false)
print('PASS deferred callback ownership, one-use/expired tokens, manual Enter/keybind visibility and failed-send cleanup')

now=170000;m=Info.new(function()return now end)
m:begin('help',true)
assert(m:onMessage('*** ACCOUNT *** /stats (/netstats) /buylevel /changepass')==true)
assert(m:onMessage('*** GENERAL *** /families /members /info')==true)
assert(m:onMessage('*** JOB *** /find /cohort')==true)
assert(m:onMessage('*** Player Name from your family has disconnected (leaving).')==false)
assert(m:onMessage('*** STAFF *** unrelated announcement')==false)
assert(m:onMessage('Newbie Player: /help me please')==false)
now=178001;m:update();assert(#m.pages.help.rows==3)
assert(m.pages.help.rows[1].text:find('/changepass',1,true),'Preserve server-supplied aliases and command references without executing them')
m:begin('help',true);m:onMessage('*** OTHER *** /jobhelp /carhelp');m:onCommand('/help',false)
assert(m:onMessage('*** JOB *** /find /cohort')==false)
m:reset();assert(not m.pages.help.updatedAt and #m.pages.help.rows==0)
print('PASS bounded server help categories, literal aliases, unrelated announcement exclusion and visible manual requests')

now=180000;server:reset();server.horizon=true;server.ready=true;server.loginSeen=true
server.character.fields.Job='Mechanic'
assert(server:requestInfo('help'))
server:update(function(command)assert(command=='/help')end,function()end,false,true,false)
now=180050;server:onOutgoing('/help')
assert(server:onMessage('*** JOB *** /fix /repair /mechduty')==true)
assert(server:onMessage('*** JOB *** /find /cohort')==true)
assert(server:onMessage('*** Person Test from your family has logged in.')==false)
now=180801;server:update(function()end,function()end,false,false,false)
assert(server.character.fields['Job 2']=='Detective','GUI help must preserve the existing missing-job inference')
server:noteManualCommand('/help');server:onOutgoing('/help')
assert(server:onMessage('*** JOB *** /find /cohort')==false)
print('PASS quiet GUI help and deferred echo coexist with job inference and visible manual help')
server:onOutgoing('/help',false)
assert(server:onMessage('*** GENERAL *** /families /members /info')==false,'Explicit diagnostic help capture must remain visible')

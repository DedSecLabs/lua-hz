package.path='src/lib/?.lua;'..package.path
local Observations=require 'horizonbase.observations'
local now=0
local function fixture()
    local rows,notices={},{}
    local o=Observations.new(function()return now end,function(s)notices[#notices+1]=s end)
    local closed=0
    local function start(mode)
        assert(o:start(function(line)rows[#rows+1]=line;return true end,function()closed=closed+1;return true end,'private-test.jsonl',mode))
    end
    return o,rows,start,function()return closed end,notices
end
local o,rows,start,closed=fixture()
for _,name in ipairs({'families','rules','members','info','settings','myguns','help'}) do
    assert(Observations.requestCommand(name)=='/'..name)
end
for _,name in ipairs({'buylevel','gvl','pvl','killcheckpoint','families extra','families\n/settings'}) do
    assert(not Observations.requestCommand(name))
end
o:onOutgoing('/families');o:event('chat',{text='no opt-in'})
assert(#rows==0 and not o.active)
start();assert(#rows==1)
o:onOutgoing('/families');o:onOutgoing('/families')
assert(o.requests==1,'Client-send and dispatch observations must not duplicate a request')
for i=1,12 do o:event('chat',{text=('* %d. Family %d | Members: 4'):format(i,i)}) end
assert(#rows==14 and rows[3]:find('1. Family 1',1,true) and rows[14]:find('12. Family 12',1,true))
o:event('chat',{text='quote" backslash\\ newline\n'..string.char(0,255)})
assert(rows[#rows]:find('\\u000a',1,true) and rows[#rows]:find('\\u0000',1,true) and rows[#rows]:find('\\u00ff',1,true))
assert(select(2,rows[#rows]:gsub('\n',''))==1,'A record must occupy one JSONL line')
now=8000;o:event('chat',{text='late response'})
assert(not o.window and not rows[#rows]:find('late response',1,true))
o:onOutgoing('/myguns');o:event('checkpoint',{x=100,y=-200,z=5});assert(rows[#rows]:find('"x":100',1,true))
o:onOutgoing('/changepass secret');local count=#rows;o:event('chat',{text='secret'})
assert(#rows==count and not table.concat(rows):find('secret',1,true))
o:onOutgoing('/families unexpected-argument');assert(not o.window)
o:onOutgoing('/info');o:dialog(5,3,'Password','secret');count=#rows
o:event('chat',{text='secret'});assert(#rows==count and not table.concat(rows):find('secret',1,true))
o:onOutgoing('/rules');o:dialog(5,0,'Rules','Full rules\nline two')
assert(rows[#rows]:find('Full rules',1,true))
o:stop('user stopped');assert(closed()==1 and not o.active)
assert(rows[#rows]:find('"event":"capture_end"',1,true) and rows[#rows]:find('user stopped',1,true))
o:stop('again');assert(closed()==1)
print('PASS opt-in, full family rows, byte-safe JSONL, request deduplication, time windows and sensitive-command/dialog exclusion')

now=0;o,rows,start,closed=fixture();start();o:onOutgoing('/members')
for i=1,100 do o:event('chat',{text='row '..i}) end
assert(not o.window and o.records<110)
o:onOutgoing('/info');o:event('dialog',{text=string.rep('x',10000)})
assert(rows[#rows]:find('"truncated":true',1,true))
now=300000;o:update();assert(not o.active and closed()==1)
now=0;o,rows,start,closed=fixture();start()
for i=1,31 do now=now+300;o:onOutgoing('/info') end
assert(not o.active and o.requests==30 and closed()==1)
now=0;o,rows,start,closed=fixture();start()
for i=1,100 do
    now=now+300;o:onOutgoing('/rules')
    for _=1,5 do o:event('dialog',{text=string.rep(string.char(255),8192)}) end
end
assert(not o.active and o.bytes<=131072 and o.records<=512 and closed()==1)
print('PASS event, text, session time, request and file-size limits')

now=0;o,rows,start,closed=fixture();start();o.single=true;o:onOutgoing('/families','explicit read-only capture')
o:event('chat',{text='1. Test Family'});now=8001;o:update()
assert(not o.active and closed()==1 and rows[#rows]:find('command window completed',1,true))
assert(rows[2]:find('explicit read-only capture',1,true))
print('PASS action-free explicit request allowlist and automatic one-command capture completion')

local closeCount=0;now=0
o=Observations.new(function()return now end)
assert(not o:start(function()return nil,'disk full' end,function()closeCount=closeCount+1;return true end,'test'))
assert(not o.active and closeCount==1 and o.captureError:find('disk full',1,true))
assert(not o:start(function()error('broken writer')end,function()return true end,'test'))
assert(o.captureError:find('broken writer',1,true))
print('PASS capture write errors close the file without affecting ordinary server behavior')

assert(Observations.version('~w~V2.4.47[Z]')=='2.4.47 [Z]')
assert(Observations.version('HZ:RP v2.4.47(z)')=='2.4.47 [Z]')
assert(not Observations.version('Player says v2.4.47[Z]'))
assert(not Observations.version('2.4.47'))
o=Observations.new(function()return now end)
o:observeTextdraw(1,'V2.4.47[Z]');assert(not o.observedVersion)
o:observeTextdraw(2,'~y~horizon_roleplay');assert(o.observedVersion=='2.4.47 [Z]')
o:hideTextdraw(1);assert(o.observedVersion=='2.4.47 [Z]','Hiding the login banner must retain this session observation')
o:observeTextdraw(3,'V2.4.48[Z]');assert(o.versionConflict)
o:reset();assert(not o.observedVersion and not o.versionConflict and not o.loginTitle)
o:update(function()error('Native scanning must never run')end)
assert(not o.observedVersion,'Update must not recover a version through native scanning')
o:observeTextdraw(1,'HZ:RP v2.4.47(z)');assert(o.observedVersion=='2.4.47 [Z]')
print('PASS contextual event-only version parsing, ambiguity and session reset without native scans')

now=0;o,rows,start,closed=fixture();start('vehicles')
o:vehicleContext({vehicle=false});local count=#rows
o:vehicleContext({vehicle=false});assert(#rows==count,'Vehicle context must not pollute capture every frame')
o:event('chat',{text='Unrelated family conversation'});assert(#rows==count)
o:event('chat',{text='You are the owner of this Test Car.'})
assert(rows[#rows]:find('"ownership":"personal"',1,true) and rows[#rows]:find('"association_unverified":true',1,true))
o:vehicleContext({vehicle=7,networkId=42,model=401,driver=false,vehicleName='Test Car',lockState=1})
o:event('chat',{text='{FFFFFF}You are in the family that owns this Test Van.'})
assert(rows[#rows]:find('"ownership":"family"',1,true) and rows[#rows]:find('"driver":false',1,true))
assert(rows[#rows]:find('"network_vehicle_id":42',1,true))
assert(not Observations.ownership('Player Test: You are the owner of this Test Car.'))
assert(not Observations.requestCommand('vstorage') and not Observations.requestCommand('car engine'))
assert(Observations.requestCommand('carhelp')=='/carhelp')
for _,command in ipairs({'/car engine','/car lights','/car window','/car hood','/car trunk','/vstorage','/trackcar 1','/trunkbalance','/pvl','/gvl','/carhelp'})do
    now=now+300;o:onOutgoing(command);assert(o.window and o.window.command==command,command)
    o:event('chat',{text='Candidate command result'})
end
for _,command in ipairs({'/car password secret','/changepass secret','/vstorage name-secret','/trackcar 1 extra','/car engine\n/changepass secret'})do
    o:onOutgoing(command);assert(not o.window,command)
end
assert(not table.concat(rows):find('secret',1,true),'Rejected outgoing text must never be logged')
o:onOutgoing('/vstorage');o:dialog(9,2,'Vehicle Storage','Test Car\nTest Van')
now=now+8100;o:update();assert(not o.window and o.vehicleDialog)
o:dialogResponse(9,1,1)
assert(rows[#rows]:find('"event":"vehicle_dialog_response"',1,true) and rows[#rows]:find('"list_index":1',1,true))
assert(o.window,'A deliberate captured selection may open its response window without sending anything')
o:event('chat',{text='Vehicle spawned at last parking location.'})
o:onOutgoing('/trackcar');o:dialog(10,2,'Track Vehicle','Test Car');o:onOutgoing('/help');count=#rows
o:dialogResponse(10,1,0);assert(#rows==count and not o.window,'Intervening commands cancel dialog ownership')
o:onOutgoing('/vstorage');o:dialog(11,2,'Vehicle Storage','Test Car');o:dialog(12,3,'Login','secret')
count=#rows;o:dialogResponse(11,1,0);assert(#rows==count and not o.window and not o.vehicleDialog)
o:onOutgoing('/vstorage');o:dialog(13,1,'Vehicle nickname','secret')
assert(not o.window and not table.concat(rows):find('secret',1,true),'Vehicle input dialogs must exclude text')
o:onOutgoing('/trackcar');o:dialog(14,2,'Track Vehicle','Test Car');now=now+60001;o:dialogResponse(14,1,0)
assert(not o.vehicleDialog and not o.window,'Stale vehicle selections must not rearm capture')
o:vehicleContext({vehicle=false});assert(rows[#rows]:find('"vehicle_handle":0',1,true))
o:stop('focus lost');count=#rows;o:vehicleContext({vehicle=8});o:event('chat',{text='You are the owner of this Test Car.'})
assert(#rows==count and closed()==1 and not o.vehicleSample and not o.vehicleDialog)
print('PASS opt-in vehicle entry/context, exact command arguments, private input exclusion, delayed dialog choices, expiry and stop cleanup')

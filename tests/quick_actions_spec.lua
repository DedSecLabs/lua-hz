package.path='tests/?.lua;src/lib/?.lua;'..package.path
local Config=require 'horizonbase.config'
local Server=require 'horizonbase.server'
local now=0;local sent,notices={},{}
local catalog={records={{name='Saved place'}}}
local s=Server.new(Config.copy(Config.defaults),function()end,function()return now end,catalog,function(text)notices[#notices+1]=text end)
s.horizon=true;s.ready=true;s.loginSeen=true
s.checkpoint={x=10};local checkpoint=s.checkpoint
s.find={active=true,id='10',name='Player Test',nextAt=0}
s.track={active=true,nextAt=0,response={id=50,list=0,input='',due=100},pendingDialog=true}
s.config.togs.repair=true;s.config.togs.taxi=true;s.config.autofind.cohort=true
s:enqueue('/find 10',0,'find');s:enqueue('/cohort 10',0,'cohort');s:enqueue('/trackcar',0,'track')
s:enqueue('/accept taxi',0,'offer',{kind='taxi'})
s:enqueue('/accept repair',0,'offer',{kind='repair',price=1})
local responses=0
local function update(eligible)s:update(function(cmd)sent[#sent+1]=cmd end,function()responses=responses+1 end,false,false,eligible)end
assert(s:requestClearNavigation());assert(not s:requestClearNavigation())
update(true);assert(#sent==1 and sent[1]=='/killcheckpoint' and s.checkpoint==checkpoint)
now=250;update(true);assert(#sent==1 and responses==0 and s.find.active and s.track.active)
assert(s:onMessage('Player: All current checkpoints, trackers and accepted fares have been reset.')==false)
assert(s.checkpoint==checkpoint,'A quoted/unrelated line is not a server acknowledgment')
assert(s:onMessage('All current checkpoints, trackers and accepted fares have been reset.')==true)
assert(not s.checkpoint and not s.find.active and not s.track.active and not s.track.response and not s.track.pendingDialog)
assert(#s.queue==1 and s.queue[1].command=='/accept repair' and #catalog.records==1,'Clear must preserve unrelated offers and saved POIs')
now=1500;update(true);assert(sent[2]=='/accept repair' and responses==0)
assert(notices[1]=='Navigation cleared.')
assert(s:onMessage('All current checkpoints, trackers and accepted fares have been reset.')==false,'Manual confirmations remain visible')

now=10000;s.checkpoint=checkpoint;s.find={active=true,id='10',name='Player Test',nextAt=50000}
assert(s:requestClearNavigation());update(true);now=15001;update(true)
assert(not s.clearNavigation and s.checkpoint==checkpoint and s.find.active,'Timeout must not claim success or discard existing tracking')
assert(notices[#notices]=='Navigation clear was not confirmed.')
now=20000;assert(s:requestClearNavigation());local before=#sent;update(false)
assert(not s.clearNavigation and #sent==before,'Blocked gameplay cancels an unsent clear')
s.horizon=false;assert(s:onMessage('All current checkpoints, trackers and accepted fares have been reset.')==false and s.checkpoint==checkpoint)
print('PASS one-shot clear, exact acknowledgment, paused requests, queue/dialog cleanup, retained POIs/offers, timeout and eligibility guards')

local im=require 'fake_imgui'
package.preload.vkeys=function()return {id_to_name=function(id)return 'Key '..id end}end
function getScreenResolution()return 1920,1080 end
function getGameTimer()return now end
local ui=require('horizonbase.ui').new(im,Config.copy(Config.defaults),function()end,function()end)
s.horizon=true;s.ready=true;s.loginSeen=true;s.find={active=false};s.track={active=false}
local actions={}
local panel=require('horizonbase.actions_ui').new(im,ui,s,function(kind,arg)actions[#actions+1]={kind=kind,arg=arg};return true end,function()return {{id=10,name='Player_Test'}}end)
panel.open[0]=true;im.clicks['Clear navigation##quickAction']=true;panel:draw()
assert(not panel.open[0] and actions[1].kind=='clear' and im.stack==0)
panel.open[0]=true;im.clicks['Lock / unlock vehicle##quickAction']=true;panel:draw();assert(actions[2].kind=='lock')
panel.open[0]=true;im.clicks['Track my vehicle##quickAction']=true;panel:draw();assert(actions[3].kind=='track')
panel.open[0]=true;im.clicks['Find player##quickAction']=true;panel:draw()
assert(panel.findMode and #actions==3,'Find opens a selector without sending a command')
im.clicks['Player_Test (10)##quickTarget10']=true;panel:draw()
assert(actions[4].kind=='find' and actions[4].arg.id==10 and actions[4].arg.name=='Player_Test')
panel:reset();assert(not panel.open[0] and not panel.findMode and #panel.targets==0)
panel.open[0]=true;panel.findMode=true;panel.targets={{id=10,name='Player_Test'}}
panel.perform=function()error('Injected action callback failure')end
im.clicks['Player_Test (10)##quickTarget10']=true
assert(not pcall(panel.draw,panel) and im.stack==0,'Selector errors must close both the child and window')
print('PASS four-action grid, deferred find selector, stable target selection, reset and balanced error cleanup')
-- Native ImGui resets the next text row to WindowPadding.x (zero in this theme).
local oldText,oldDisabled,oldButton=im.TextUnformatted,im.TextDisabled,im.Button
local status,buttons={},{}
local function text(label)
    status[label]={x=im.cursor.x,y=im.cursor.y};im.cursor.x=0
end
im.TextUnformatted=text;im.TextDisabled=text
im.Button=function(label,size)
    buttons[label]={x=im.cursor.x,y=im.cursor.y,height=size and size.y}
    return oldButton(label,size)
end
s.checkpoint=nil;panel:reset();panel.open[0]=true;panel:draw()
assert(status['No checkpoint received'].x==status['Player finding is off'].x and status['Player finding is off'].x==status['Vehicle tracking is off'].x,'Status rows must keep one explicit left margin despite native cursor reset')
panel.findMode=true;panel:draw()
local find,back,refresh=buttons['Find##submitTarget'],buttons['Back##actions'],buttons['Refresh##quickPlayers']
assert(find.y==back.y and back.y==refresh.y and find.height==back.height and back.height==refresh.height,'Find/Back/Refresh must share a baseline and height')
assert(find.x==status['Find player'].x and status['Find player'].x==status['Detective job required.'].x and status['Name or ID'].x==find.x,'Selector title, hint, input label and toolbar must share their inset')
im.TextUnformatted,im.TextDisabled,im.Button=oldText,oldDisabled,oldButton
print('PASS native-cursor-reset status alignment and equal-sized selector toolbar with concise Refresh label')

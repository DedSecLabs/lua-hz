package.path='src/lib/?.lua;'..package.path
local ip,port,state='192.0.2.10',7777,3
function script_name()end;function script_author()end;function script_version()end;function script_description()end
package.preload['lib.moonloader']=function()return {}end
function isSampLoaded()return true end;function isSampfuncsLoaded()return true end
function isSampAvailable()return true end
function sampGetGamestate()return state end
function sampGetCurrentServerAddress()return ip,port end
function wait()coroutine.yield()end
local created,started,ticks,stopped,presents,windows,terminated=0,0,0,0,0,0,0
local active=false
local forbidden={'horizonbase.config','horizonbase.game','horizonbase.ui_backend','samp.events','horizonbase.limiter'}
for _,name in ipairs(forbidden) do package.preload[name]=function()error('Foreign-server dependency load: '..name)end end
package.preload['horizonbase.runtime']=function()
    return {new=function(authorized)
        assert(authorized());created=created+1
        return {start=function()if not active then active=true;started=started+1 end end,
            stop=function()if active then active=false;stopped=stopped+1 end end,
            tick=function()assert(authorized());ticks=ticks+1 end,
            present=function()assert(authorized());presents=presents+1 end,
            window=function()assert(authorized());windows=windows+1 end,
            terminate=function()terminated=terminated+1 end}
    end}
end
local script={};function thisScript()return script end
assert(loadfile('src/HorizonBase.lua'))()
local mainThread=coroutine.create(main)
local function step()local ok,err=coroutine.resume(mainThread);assert(ok,err)end
step();step();onD3DPresent();onWindowMessage(0x100,120,0)
assert(created==0 and started==0 and ticks==0 and presents==0 and windows==0)
for _,name in ipairs(forbidden) do assert(not package.loaded[name]) end
ip='213.32.6.232';port=7778;step();assert(created==0)
port=7777;step();assert(created==1 and started==1 and ticks==1)
onD3DPresent();onWindowMessage(0x100,120,0);assert(presents==1 and windows==1)
ip='192.0.2.10'
onWindowMessage(0x100,120,0);assert(stopped==1 and windows==1)
onD3DPresent();step();assert(presents==1 and ticks==1)
ip='213.32.6.232';step();assert(created==1 and started==2 and ticks==2)
state=5;onD3DPresent();assert(stopped==2 and presents==1)
state=3;step();assert(started==3)
onScriptTerminate({});assert(terminated==0)
onScriptTerminate(script);assert(terminated==1)
print('PASS other-server bootstrap isolation and HZ/foreign/HZ reuse without feature loads elsewhere')

script_name('LuaHZ')
script_author('LuaHZ contributors')
script_version('0.4.0-rc.3')
script_description('Horizon Gaming only: endpoint-gated MoonLoader helper')
require 'lib.moonloader'

-- This bootstrap is the only code loaded on other servers. It performs no
-- configuration writes, UI setup, command registration or gameplay changes.
local Gate=require 'horizonbase.server_gate'
local runtime
local failed=false
local focused=true
local function synchronize()
    if not Gate.current() then
        if runtime then runtime.stop() end
        return false
    end
    if not runtime and not failed then
        local ok,result=pcall(function()return require('horizonbase.runtime').new(Gate.current,function()return focused end)end)
        if ok then runtime=result else failed=true;print('[LuaHZ] HZ runtime could not initialize: '..tostring(result)) end
    end
    if runtime then runtime.start();return true end
    return false
end

function main()
    while true do
        if synchronize() then runtime.tick() end
        wait(runtime and 0 or 100)
    end
end

function onWindowMessage(...)
    local msg,key=...
    if msg==0x0008 or msg==0x001C and key==0 then focused=false
    elseif msg==0x0007 or msg==0x001C and key~=0 then focused=true end
    if runtime and synchronize() then return runtime.window(...) end
end
function onD3DPresent()
    if runtime and synchronize() then runtime.present() end
end
function onScriptTerminate(scr)
    if scr==thisScript() and runtime then runtime.terminate() end
end

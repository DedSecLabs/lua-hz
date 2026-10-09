-- Minimal, side-effect-free gate. No UI, configuration, files or network I/O.
local M={ip='213.32.6.232',port=7777}
-- Installed SAMPFUNCS constants: waiting=1, awaiting join=2, connected=3,
-- restarting=4. None=0 and disconnected=5 always deactivate the runtime.
local states={[1]=true,[2]=true,[3]=true,[4]=true}

function M.matches(ip,port)
    return type(ip)=='string' and ip==M.ip and type(port)=='number' and port==M.port
end

local function read(name,...)
    local fn=_G[name]
    if type(fn)~='function' then return nil end
    local ok,a,b=pcall(fn,...)
    if not ok then return nil end
    return a,b
end

function M.current()
    if read('isSampLoaded')~=true or read('isSampfuncsLoaded')~=true or read('isSampAvailable')~=true then
        return false
    end
    local state=read('sampGetGamestate')
    if not states[state] then return false end
    local ip,port=read('sampGetCurrentServerAddress')
    return M.matches(ip,port),state
end

return M

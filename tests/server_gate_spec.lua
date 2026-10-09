package.path='src/lib/?.lua;'..package.path
local Gate=require 'horizonbase.server_gate'
assert(Gate.matches('213.32.6.232',7777))
for _,pair in ipairs({{'213.32.6.232',7778},{'213.32.6.233',7777},
    {'samp.hzgaming.net',7777},{'Horizon Roleplay',7777},{'213.32.6.232.attacker.test',7777},
    {' 213.32.6.232',7777},{'213.32.6.232','7777'}}) do
    assert(not Gate.matches(pair[1],pair[2]))
end
assert(not Gate.matches(nil,7777));assert(not Gate.matches('213.32.6.232',nil))
local state,ip,port=3,'213.32.6.232',7777
function isSampLoaded()return true end
function isSampfuncsLoaded()return true end
function isSampAvailable()return true end
function sampGetGamestate()return state end
function sampGetCurrentServerAddress()return ip,port end
for _,s in ipairs({1,2,3,4}) do state=s;assert(Gate.current()) end
for _,s in ipairs({0,5,6,-1,100}) do state=s;assert(not Gate.current()) end
state=3
for _,fn in ipairs({'isSampLoaded','isSampfuncsLoaded','isSampAvailable','sampGetGamestate','sampGetCurrentServerAddress'}) do
    local old=_G[fn]
    _G[fn]=nil;assert(not Gate.current())
    _G[fn]=function()error('native unavailable')end;assert(not Gate.current())
    _G[fn]=old
end
ip='192.0.2.10';assert(not Gate.current())
ip='213.32.6.232';port=7778;assert(not Gate.current())
print('PASS exact IP/port authorization, closed states and missing/error native APIs')

local base=0x10000000
_G.browser=false;_G.held=false
local calls=0
local words={[base+0x3c]=0x80,[base+0x88]=0x69430243,[base+0xa8]=0xb23e4,[base+0xd0]=0x219000,[base+0x4072e]=base+0x1d1690}
local bytes={[base+0x40727]=0x83,[base+0x40728]=0xfb,[base+0x40729]=0x78,[base+0x4072c]=0x80,[base+0x4072d]=0x3d,[base+0x40732]=0}
local api={module=function()calls=calls+1;return base end,
 readable=function(address,n)return address>=base and address+n<=base+0x219000 end,
 word=function(address)return words[address]end,
 byte=function(address)if address==base+0x1d1690 then return _G.browser and 1 or 0 end;return bytes[address]end,
 down=function(code)assert(code==123);return _G.held end}
local Compat=assert(loadfile('src/lib/horizonbase/openmp_compat.lua'))()
local original=Compat.new
local foreign=original(function()return false end,api)
assert(not foreign.state() and not foreign:pollKey(123,0) and calls==0,'Foreign calls must not initialize native inspection')
local probe=original(function()return true end,api)
assert(probe.state()==true)
words[base+0x88]=1;assert(probe.state()==false);words[base+0x88]=0x69430243
bytes[base+0x40727]=0x90;assert(probe.state()==false);bytes[base+0x40727]=0x83
package.preload['horizonbase.openmp_compat']=function()
 return {new=function(auth)return original(auth,api)end}
end
package.preload['horizonbase.runtime']=function()return assert(loadfile('src/lib/horizonbase/runtime.lua'))()end
local f=assert(io.open('tests/startup_spec.lua','rb'));local source=f:read('*a');f:close()
source=source:gsub("return {modifiers={quickmap=4}","return {keybinds={settingsPanel=123},modifiers={quickmap=4}")
source=source:gsub('onWindowMessage%(0x0100,120,0%)','onWindowMessage(0x0100,123,0)')
local marker="rawPrint('PASS entry-point startup and login-gated HUD frame')"
local checks=[[
browser=true;tick();assert(not frames[1].Condition(),'Open.mp browser must hide HUD')
local old=consumed;onWindowMessage(0x0100,123,0);assert(consumed==old,'Open.mp browser must retain its keyboard')
browser=false;gameClock=gameClock+200;tick();assert(frames[1].Condition(),'Closing browser must restore HUD')
held=true;tick();assert(frames[3].Condition(),'Missing F12 window event must still open settings')
gameClock=gameClock+8;onWindowMessage(0x0100,123,0)
assert(frames[3].Condition(),'A late window event must not close the menu opened by polling')
tick();assert(frames[3].Condition(),'Held F12 must not toggle repeatedly')
held=false;tick();gameClock=gameClock+200;held=true;tick();assert(not frames[3].Condition(),'Polling must also close settings')
gameClock=gameClock+8;onWindowMessage(0x0100,123,0)
assert(not frames[3].Condition(),'A late window event must not reopen the menu closed by polling')
held=false;tick();gameClock=gameClock+200
held=true;onWindowMessage(0x0100,123,0);tick();assert(frames[3].Condition(),'Delivered key and polling must toggle only once')
held=false;tick();gameClock=gameClock+200;onWindowMessage(0x0100,27,0);consumed=old
gameClock=1000
rawPrint('PASS verified open.mp browser HUD suppression, F12 polling, release edge and event/poll deduplication')
]]
local pos=assert(source:find(marker,1,true))+#marker
source=source:sub(1,pos)..'\n'..checks..source:sub(pos+1)
assert(loadstring(source,'@tests/startup_spec.lua + local open.mp checks'))()

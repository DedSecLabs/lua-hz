package.path='tests/?.lua;src/lib/?.lua;'..package.path
local ffi=require 'ffi'
ffi.cdef('typedef void* HWND; typedef void* LPDIRECT3DDEVICE9;')
local im=require 'fake_imgui'
local handler,worker,loadedFonts,defaultCount,exists
local nativeCreates,nativeFrames,cursor,playerLock,consumed=0,0,false,false,0
function getMoonloaderVersion()return 26 end
function getWorkingDirectory()return 'C:\\Test\\moonloader'end
function getFolderPath()return 'C:\\windows\\Fonts'end
function readMemory()return 1 end;function getD3DDevicePtr()return 1 end
function doesDirectoryExist()return true end;function createDirectory()end
function doesFileExist(path)return exists[path] or false end
function addEventHandler(name,fn)handler[name]=fn end
function wait()coroutine.yield()end
function showCursor(value)cursor=value end;function lockPlayerControl(value)playerLock=value end
function consumeWindowMessage()consumed=consumed+1 end
function isCursorActive()return false end
script={this={filename='HorizonBase.lua'}}
lua_thread={create=function(fn)worker=coroutine.create(fn);assert(coroutine.resume(worker));return {}end}
local fonts={}
function fonts:GetGlyphRangesCyrillic()return ffi.new('unsigned short[3]',32,127,0)end
function fonts:AddFontFromFileTTF(path)loadedFonts[#loadedFonts+1]=path end
function fonts:AddFontDefault()defaultCount=defaultCount+1 end
local io={Fonts=fonts}
function im.GetIO()return io end
function im.ImFontGlyphRangesBuilder()return {AddRanges=function()end,AddText=function()end,BuildRanges=function()end}end
function im.ImVector_ImWchar()return {[0]={Data=ffi.new('unsigned short[3]',32,127,0)}}end
im.lib={ImGuiMouseCursor_None=0};function im.SetMouseCursor()end
local renderer={SwitchContext=function()end,NewFrame=function()nativeFrames=nativeFrames+1 end,EndFrame=function()end,WindowMessage=function()end}
package.preload['mimgui.imgui']=function()return im end
package.preload['mimgui.dx9']=function()return {new=function()nativeCreates=nativeCreates+1;return renderer end}end
package.preload['memory']=function()return {}end
package.preload['windows.message']=function()
    local n=0
    return setmetatable({},{__index=function(t,k)n=n+1;rawset(t,k,n);return n end})
end
local function check(name,available,expected)
    exists=available;handler={};loadedFonts={};defaultCount=0;package.loaded['horizonbase.ui_backend']=nil
    local backend=require 'horizonbase.ui_backend'
    local sub=backend.OnFrame(function()return true end,function()end);sub.HideCursor=true
    assert(coroutine.resume(worker))
    handler.onD3DPresent()
    if expected then assert(loadedFonts[1]==expected,'Wrong font selected');assert(defaultCount==0)
    else assert(defaultCount==1,'Missing font fallback did not initialize');assert(#loadedFonts==0) end
    print('PASS '..name)
end
check('missing Windows and resource fonts use built-in font',{},nil)
local rubik='C:\\Test\\moonloader\\resource\\horizonbase\\fonts\\Rubik\\Rubik-Regular.ttf'
check('local Rubik avoids a Windows font requirement',{[rubik]=true},rubik)
local trebuchet='C:\\windows\\Fonts\\trebucbd.ttf'
check('available Windows font is a valid fallback',{[trebuchet]=true},trebuchet)

-- Real backend handlers must re-check the endpoint even before the main-loop
-- cleanup gets a turn. A stale active frame cannot capture input elsewhere.
handler={};exists={};loadedFonts={};defaultCount=0;package.loaded['horizonbase.ui_backend']=nil
local backend=require 'horizonbase.ui_backend'
local allowed=false
backend.SetActivationCheck(function()return allowed end)
local sub=backend.OnFrame(function()return true end,function()end)
sub.HideCursor=false;sub.LockPlayer=true
local beforeCreates,beforeFrames=nativeCreates,nativeFrames
assert(coroutine.resume(worker));handler.onD3DPresent()
assert(nativeCreates==beforeCreates and nativeFrames==beforeFrames and not cursor and not playerLock)
allowed=true;assert(coroutine.resume(worker));handler.onD3DPresent()
assert(nativeCreates==beforeCreates+1 and cursor and playerLock)
local count=nativeFrames
allowed=false
handler.onWindowMessage(0x0100,120,0)
assert(not cursor and not playerLock and consumed==0)
handler.onD3DPresent();assert(nativeFrames==count and not sub:IsActive())
allowed=true;assert(coroutine.resume(worker));handler.onD3DPresent()
assert(nativeCreates==beforeCreates+1 and nativeFrames==count+1)
print('PASS native renderer stays uninitialized outside HZ and releases stale cursor/control locks immediately')

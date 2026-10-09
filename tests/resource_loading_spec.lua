package.path='tests/?.lua;src/lib/?.lua;src/lib/?/init.lua;'..package.path
local im=require 'fake_imgui'
local paths={}
function getWorkingDirectory()return 'C:\\Test\\moonloader'end
function doesFileExist()return true end
im.CreateTextureFromFile=function(path)paths[#paths+1]=path;return #paths end
local o=require('horizonbase.overlay').new(im,{}, {}, {})
o:initialize()
assert(#paths==3,'Startup must upload only the essential HUD textures')
assert(o:warmupPending())
while o:warmupPending() do
    local before=#paths;o:warmupStep()
    assert(#paths-before<=1,'Optional texture uploads must be bounded to one per frame')
end
for i=1,36 do assert(o.tiles[i],'Every quickmap tile must eventually load')end
for i=0,46 do assert(o.textures['weaponicons/'..i..'.png'])end
local count=#paths;o:warmupStep();o:texture('weaponicons/24.png')
assert(#paths==count,'Completed uploads and texture cache must not reload files')
print('PASS bounded startup uploads, complete map/weapon warmup and caching')

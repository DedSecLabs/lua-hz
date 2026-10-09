package.path='tests/?.lua;src/lib/?.lua;'..package.path
local im=require 'fake_imgui'
local icons=require 'horizonbase.map_icons'
local Overlay=require 'horizonbase.overlay'
local lines=icons.diagnostics({
    [9]={kind=52,color=0xFF1122AA,style=1,position={x=123.25,y=-456.5,z=12}},
    [2]={kind=0,color=-1,style=0,position={x=1,y=2,z=3}},
    [12]={kind=99,color=0,style=3,position={x=5,y=6,z=7}}
})
assert(lines[1]:find('active=3',1,true))
assert(lines[2]:find('id=2 type=0 sprite=Colored marker rgba=0xFFFFFFFF',1,true))
assert(lines[3]:find('id=9 type=52 sprite=Robbery rgba=0xFF1122AA',1,true))
assert(lines[3]:find('style=1 x=123.25 y=-456.50 z=12.00',1,true))
assert(lines[4]:find('sprite=Unknown sprite',1,true))
assert(icons.diagnostics({})[2]:find('before connecting',1,true))
assert(icons.name(63)=="Pay 'n' Spray" and icons.name(22)=='Hospital')
print('PASS sorted server icon diagnostics retain type, signed RGBA, style and coordinates; unknown sprites stay unknown')

local overlay=Overlay.new(im,{}, {}, {})
local texture={};overlay.texture=function()return texture end
im.U32=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end
local quads,triangles={},{}
local dl={}
function dl:AddImageQuad(tex,a,b,c,d,uvA,uvB,uvC,uvD,color)
    assert(tex==texture)
    assert(uvA.x==0 and uvA.y==0 and uvB.x==1 and uvB.y==0 and uvC.x==1 and uvC.y==1 and uvD.x==0 and uvD.y==1)
    quads[#quads+1]={a,b,c,d,color=color}
end
function dl:AddTriangleFilled(a,b,c,color)triangles[#triangles+1]={a,b,c,color=color}end
local function near(a,b)assert(math.abs(a-b)<.001)end
for _,heading in ipairs({0,90,180,270,45}) do
    quads={};overlay:playerMapIcon(dl,300,400,heading,32)
    local main=quads[#quads]
    near((main[1].x+main[3].x)/2,300);near((main[1].y+main[3].y)/2,400)
    local frontX,frontY=(main[1].x+main[2].x)/2,(main[1].y+main[2].y)/2
    near(frontX,300-16*math.sin(math.rad(heading)))
    near(frontY,400-16*math.cos(math.rad(heading)))
    assert(main.color.r==1 and main.color.a==1)
    assert(#quads>1 and quads[1].color.r<.1 and quads[1].color.a==1,'Opaque dark outline needed on white map areas')
end
overlay.texture=function()return nil end
overlay:playerMapIcon(dl,300,400,90,32)
assert(#triangles==2 and triangles[1].color.r<.1 and triangles[2].color.r==1)
assert(triangles[1][1].x<triangles[2][1].x,'Fallback outline must extend beyond the white arrow')
print('PASS player sprite retains heading/center/UVs and contrast; missing texture uses an outlined fallback')

-- Exercise the distinct types received in the real Horizon session, including
-- native sprites whose color field is zero. These must retain their own colors.
local observed={5,6,12,14,17,20,23,24,26,29,31,42,43,45,48,50,51,54,55}
-- Type 23 occurs twice, but uses one distinct texture.
local images,rects={},{}
local requested
overlay.texture=function(_,path)requested=path;return texture end
function dl:AddImage(tex,a,b,uvA,uvB,color)
    assert(tex==texture);images[#images+1]={a=a,b=b,color=color}
end
function dl:AddRectFilled(a,b,color)rects[#rects+1]={a=a,b=b,color=color}end
for _,kind in ipairs(observed) do
    images={};overlay:serverMapIcon(dl,{kind=kind,color=0},300,400,22,.6)
    assert(requested=='ui-v0212/'..icons.file(kind))
    local main=images[#images]
    assert(main and main.color.r==1 and main.color.g==1 and main.color.b==1 and main.color.a==.6,'Sprite must keep intrinsic color/opacity even when server RGBA is zero')
    near((main.a.x+main.b.x)/2,300);near((main.a.y+main.b.y)/2,400)
    near(main.b.x-main.a.x,22)
end
assert(icons.file(2)=='radar_centre.png' and icons.file(3)=='arrow.png')
assert(icons.file(23)=='Jizzy.png' and icons.file(31)=='radar_propertyG.png')
assert(icons.file(32)=='radar_propertyR.png' and icons.file(58)=='radar_gangB.png')
assert(icons.file(59)=='radar_gangP.png' and icons.file(63)=='radar_spray.png')
assert(icons.file(0)==nil and icons.file(1)==nil and icons.file(99)==nil and icons.file(nil)==nil)
print('PASS captured Horizon sprite types use colored HD artwork, independent of zero server RGBA, with centered bounds')

rects={};overlay:serverMapIcon(dl,{kind=0,color=0xFF1122AA},300,400,22,.5)
assert(#rects==2)
local color=rects[2].color
near(color.r,1);near(color.g,17/255);near(color.b,34/255);near(color.a,170/255*.5)
rects={};overlay:serverMapIcon(dl,{kind=0,color=0},300,400,22,.5);assert(#rects==0)
overlay.texture=function()return nil end
rects={};overlay:serverMapIcon(dl,{kind=6,color=0},300,400,22,.5)
assert(#rects==2 and rects[2].color.r==1 and rects[2].color.a==.5)
print('PASS generic marker RGBA/transparent handling and missing-sprite fallback')

local catalog=require('horizonbase.location_catalog').new('/fake')
catalog.address='Horizon Roleplay'
catalog:observe({kind=31,position={x=10,y=20,z=5}})
catalog:observe({kind=29,position={x=200,y=300,z=5}})
local prefs={quickmap={opacity=80,rememberLocations=true,gangzones=false}}
local server={iconsRevision=1,icons={[7]={kind=6,position={x=10,y=20,z=5},color=0}},catalog=catalog}
local world=Overlay.new(im,prefs,{sample={ready=false}},server)
world.texture=function()return texture end
function getScreenResolution()return 1920,1080 end
function dl:PushClipRect()end;function dl:PopClipRect()end
local captions={}
function dl:AddText(pos,color,text)captions[#captions+1]=text end
im.GetBackgroundDrawList=function()return dl end
images={};world:map()
assert(#images==10,'One saved-only icon plus one live icon, each with an outline')
near(images[5].color.a,.8);near(images[10].color.a,.8)
assert(#captions==2 and not captions[1]:find('saved'),'No live/saved labels should clutter the map')
prefs.quickmap.rememberLocations=false;images={};world:map();assert(#images==5)
print('PASS remembered and live icons match opacity, fresh icons suppress duplicates, and the remember toggle works')

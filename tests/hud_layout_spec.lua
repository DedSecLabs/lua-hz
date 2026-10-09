package.path='tests/?.lua;src/lib/?.lua;'..package.path
local im=require 'fake_imgui'
local Config=require 'horizonbase.config'
local Overlay=require 'horizonbase.overlay'
function getGameTimer()return 100 end
function displayHud()end
function displayRadar()end
function sampTextdrawIsExists()return false end
im.U32=function(r,g,b,a)return {r,g,b,a}end
local images,rects,texts,quads={},{},{},{}
local dl={}
function dl:AddRectFilled(a,b,color,r)rects[#rects+1]={a=a,b=b,color=color,r=r or 0}end
function dl:AddTextFontPtr(font,size,pos,color,text)texts[#texts+1]={size=size,pos=pos,text=text}end
function dl:AddImage(tex,a,b,uv1,uv2,color)images[#images+1]={tex=tex,a=a,b=b,color=color}end
function dl:AddImageQuad(tex,a,b,c,d,uv1,uv2,uv3,uv4,color)
    images[#images+1]={tex=tex,a={x=math.min(a.x,b.x,c.x,d.x),y=math.min(a.y,b.y,c.y,d.y)},
        b={x=math.max(a.x,b.x,c.x,d.x),y=math.max(a.y,b.y,c.y,d.y)},color=color}
end
function dl:AddQuadFilled(a,b,c,d,color)quads[#quads+1]={a=a,b=b,c=c,d=d}end
function dl:AddText()end
im.GetBackgroundDrawList=function()return dl end
local server={horizon=false,find={active=false},track={active=false}}
local sample={ready=true,hour=22,minute=56,weapon=0,money=123456789,health=100,armour=60,wanted=6,
    stamina=.5,oxygen=.4,running=true,swimming=false,swimState=0,vehicle=false,
    speed=123,vehicleHealth=999,vehicleName='A very long police vehicle name that must stay inside its area'}
local game={sample=sample,cruise={active=true,target=120}}
local prefs=Config.copy(Config.defaults)
local o=Overlay.new(im,prefs,game,server)
o.texture=function(_,rel)
    if rel=='hud-v0218/hud-font.png'then return 1 end
    if rel=='weaponicons/0.png'then return 2 end
    if rel=='hud-v0218/wanted-star.png'then return 3 end
    if rel:find('dashboard%-v0221/')then return 4 end
end
for _,screen in ipairs({{1920,1080},{1280,720},{640,480},{320,1080}})do
    function getScreenResolution()return screen[1],screen[2]end
    for _,pct in ipairs({50,100,200})do
        prefs.hud.scale=pct
        for _,mode in ipairs({1,2})do
            prefs.settings.vdb=mode
            for _,kind in ipairs({'vehicle','stamina','oxygen'})do
                sample.locked=false
                sample.vehicle=kind=='vehicle' and 1 or false
                sample.swimming=kind=='oxygen';sample.swimState=kind=='oxygen' and 3 or 0
                sample.oxygen=kind=='oxygen' and .4 or 1
                images={};rects={};quads={};o:hud()
                local scale=o.hudScale;local weapon,stars,tracks=0,0,0
                for _,v in ipairs(images)do
                    assert(v.a.x>=-.01 and v.a.y>=-.01 and v.b.x<=screen[1]+.01 and v.b.y<=screen[2]+.01,('HUD image escaped viewport %dx%d scale=%d mode=%d kind=%s tex=%d rect=%.2f,%.2f -> %.2f,%.2f'):format(screen[1],screen[2],pct,mode,kind,v.tex,v.a.x,v.a.y,v.b.x,v.b.y))
                    if v.tex==2 then weapon=weapon+1 end
                    if v.tex==3 and v.color[1]>0 then
                        stars=stars+1;assert(v.color[1]==1 and v.color[2]==.86 and v.color[3]==.10,'Wanted fill must be yellow')
                    end
                end
                for _,r in ipairs(rects)do
                    assert(r.r==0 or r.r==10*scale,'Only dashboard backing may be rounded')
                    assert(r.a.x>=0 and r.a.y>=0 and r.b.x<=screen[1]+.01 and r.b.y<=screen[2]+.01,'HUD bar escaped viewport')
                    if r.color[1]==0 and r.color[2]==0 and r.color[3]==0 then
                        tracks=tracks+1;local bh=(r.b.y-r.a.y)/scale;assert(math.abs(bh-22)<.01 or math.abs(bh-16)<.01,'Native/dashboard bar outer height differs')
                    end
                end
                assert(weapon==1 and stars==6 and tracks==3)
                assert(#quads==0,'Dashboard must use straight square bars, not segmented gauges')
                for _,v in ipairs(images)do
                    if v.tex==4 then assert(math.abs(v.b.x-v.a.x-36*scale)<.01 and math.abs(v.b.y-v.a.y-36*scale)<.01,'All dashboard icons must share the larger size')end
                end
                local box=require('horizonbase.dashboard').layout(screen[1],screen[2],scale,kind=='vehicle'and(mode==2 and'minimal'or'full')or'energy',false)
                assert(math.abs(box.x+box.width-(screen[1]-12*scale))<.01,'Dashboard must be anchored to the right edge')
                assert(#images>80,'Actual bitmap rendering must be exercised')
            end
        end
    end
end
sample.wanted=0;images={};rects={};quads={};o:hud()
for _,v in ipairs(images)do assert(v.tex~=3,'Inactive wanted stars must not appear')end
-- Observe actual dashboard text calls to verify blank digit slots and fixed units.
local Dashboard=require 'horizonbase.dashboard'
local originalText=o.nativeText
local calls={};local paths={}
o.nativeText=function(_,draw,pos,color,value,size)calls[#calls+1]={value=value,pos=pos,size=size}end
o.texture=function(_,path)paths[#paths+1]=path;return 4 end
prefs.settings.vdb=1;sample.vehicle=1;sample.locked=false;game.cruise.active=false
local mphX,mphY,numberSize
local speedY=Dashboard.layout(1920,1080,1,'full').y+50
for _,speed in ipairs({0,7,10,99,100,111,888,999})do
    calls={};sample.speed=speed;sample.vehicleHealth=500
    Dashboard.draw(o,dl,sample,1,1920,1080,false,false)
    local digits=''
    for _,call in ipairs(calls)do
        if call.value=='MPH'then
            if mphX then assert(call.pos.x==mphX and call.pos.y==mphY,'MPH must not jump as speed changes')end
            mphX=call.pos.x;mphY=call.pos.y
        elseif call.pos.y==speedY then
            digits=digits..call.value
            if numberSize then assert(numberSize==call.size,'Speed font size must remain fixed')end
            numberSize=call.size
        end
    end
    assert(digits==tostring(speed),'Speed must have no leading zeros')
    assert(calls[#calls-1].value=='50' and calls[#calls].value=='%','Vehicle health must display 0–100%')
end
for _,health in ipairs({-10,0,250,500,999,1000,1500})do
    calls={};sample.vehicleHealth=health
    Dashboard.draw(o,dl,sample,1,1920,1080,false,false)
    local expected=tostring(math.floor(math.max(0,math.min(health/1000,1))*100))
    assert(calls[#calls-1].value==expected,'Vehicle health percent must clamp to 0–100')
end
sample.vehicle=false
for _,oxygen in ipairs({false,true})do
    calls={};paths={}
    Dashboard.draw(o,dl,sample,1,1920,1080,not oxygen,oxygen)
    assert(#calls==0,'Energy display must contain only icon and bar')
    assert(paths[1]=='dashboard-v0221/'..(oxygen and 'swimming-filled' or 'run')..'.png','Requested energy artwork must be used')
end
o.nativeText=originalText
-- Optional local bitmap assets may be absent in a source-only install.
o.texture=function()return nil end;sample.money=-50;images={};texts={};o:hud()
assert(#texts>0,'Missing textures must still leave readable time/cash/status text')
print('PASS native HUD bitmap/bar bounds, retained weapon art, yellow active stars, full/minimal/energy modes and texture fallback')

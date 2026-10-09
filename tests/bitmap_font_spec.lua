package.path='tests/?.lua;src/lib/?.lua;'..package.path
local im=require 'fake_imgui'
local Bitmap=require 'horizonbase.bitmap_font'
local calls={};local dl={}
function dl:AddImage(tex,a,b,uv1,uv2,color)
    assert(tex==17 and b.x>a.x and b.y>a.y)
    assert(uv1.x>=0 and uv1.y>=0 and uv2.x<=1 and uv2.y<=1)
    calls[#calls+1]={a=a,b=b}
end
local font=Bitmap.new(im,function(path)assert(path=='hud-v0218/hud-font.png');return 17 end)
assert(font:width('22:56',48,'pricedown')>0)
assert(font:width('1234',64,'pricedown')==2*font:width('1234',32,'pricedown'))
assert(font:width('Tornado',32,'gothic')==font:width('TORNADO',32,'gothic'))
assert(font:draw(dl,'$00005249',10,20,48,'pricedown',1,3))
assert(#calls==9*9,'Eight outline passes plus visible glyphs')
local w=font:width('$00005249',48,'pricedown')
for _,c in ipairs(calls)do assert(c.a.x>=7 and c.b.x<=10+w+3 and c.a.y>=17 and c.b.y<=71)end
local skewed=0
function dl:AddImageQuad(tex,a,b,c,d,uv1,uv2,uv3,uv4,color)
    assert(a.x>d.x and b.x>c.x,'Italic text must shear its top edge')
    skewed=skewed+1
end
assert(font:draw(dl,'123',10,20,48,'pricedown',1,1,.12));assert(skewed==27)
font.texture=function()return nil end
assert(not font:draw(dl,'12',10,20,48,'pricedown',1,3))
print('PASS bitmap font UVs, advances, scaled width, uppercase dashboard text, outlines and missing-texture fallback')

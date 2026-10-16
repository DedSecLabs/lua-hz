-- A strict interface harness, not a native renderer. Used to exercise UI/overlay branches.
local ffi=require 'ffi'
local im={clicks={},stack=0,cursor={x=0,y=0},drawCalls=0,drawTexts={}}
local function vec2(x,y) return {x=x or 0,y=y or 0} end
im.ImVec2=vec2
function im.ImVec4(x,y,z,w) return {x=x,y=y,z=z,w=w} end
function im.U32() return 4294967295 end
local enum=setmetatable({},{__index=function(t,k)local n=#t+1;rawset(t,k,n);return n end})
for _,name in ipairs({'Col','Cond','WindowFlags','InputTextFlags','StyleVar'}) do im[name]=enum end
im.Cond={Always=1,FirstUseEver=4}
local new={}
setmetatable(new,{__index=function(_,name)
    local base=ffi.typeof(name)
    return setmetatable({},{__call=function(_,value)return ffi.new(ffi.typeof('$[1]',base),value) end,
        __index=function(_,n)return function(value)return ffi.new(ffi.typeof('$[?]',base),n,value) end end})
end})
im.new=new
local style={Colors={}}
function im.GetStyle() return style end
local io={FontGlobalScale=1}
function im.GetIO()return io end
local font={FontSize=15}
function font:FindGlyph()return {X0=0,Y0=0,X1=7,Y1=15,AdvanceX=7}end
function im.GetFont()return font end
function im.GetFontSize()return 15*io.FontGlobalScale end
function im.SetWindowFontScale()end
function im.GetScreenSize() return vec2(1920,1080) end
function im.GetWindowSize() return vec2(660,490) end
function im.GetWindowPos() return vec2(600,300) end
function im.GetWindowWidth() return 660 end
function im.GetContentRegionAvail() return vec2(427,420) end
function im.GetCursorScreenPos() return vec2(im.cursor.x,im.cursor.y) end
function im.SetCursorScreenPos(v) im.cursor=vec2(v.x,v.y) end
function im.SetCursorPos(v) im.cursor=vec2(v.x,v.y) end
function im.SetNextWindowSizeConstraints(minimum,maximum)assert(minimum.y>0 and maximum.y>=minimum.y)end
function im.SetNextWindowSize(v) assert(type(v.x)=='number');im.lastWindowSize=v end
function im.SetNextWindowPos(v,condition) assert(type(v.x)=='number');im.lastPositionCondition=condition end
function im.Begin() im.stack=im.stack+1;return true end
function im.End() im.stack=im.stack-1 end
function im.BeginChild() im.stack=im.stack+1;return true end
function im.EndChild() im.stack=im.stack-1 end
for _,name in ipairs({'TextUnformatted','TextDisabled','TextWrapped','BulletText','TextColored','AlignTextToFramePadding',
    'Separator','Spacing','SameLine','PushStyleColor','PopStyleColor','PushItemWidth','PopItemWidth'}) do
    im[name]=function() end
end
local function clicked(label)
    local value=im.clicks[label];im.clicks[label]=nil
    return value or false
end
function im.Button(label,size) if size then assert(type(size.x)=='number') end;return clicked(label) end
im.SmallButton=im.Button;im.InvisibleButton=im.Button
function im.InputInt(_,ptr) assert(type(ptr)=='cdata');return false end
im.sliders={}
function im.SliderInt(label,ptr)
    assert(type(ptr)=='cdata')
    if im.sliders[label]~=nil then ptr[0]=im.sliders[label];im.sliders[label]=nil;return true end
    return false
end
function im.Combo(_,ptr,items,count)
    assert(type(ptr)=='cdata' and type(items)=='cdata' and type(count)=='number','Combo requires a pointer array and item count')
    return false
end
function im.PushStyleVarVec2(_,value)assert(type(value.x)=='number')end
function im.PopStyleVar()end
function im.BeginCombo()im.stack=im.stack+1;return true end
function im.EndCombo()im.stack=im.stack-1 end
function im.Selectable(label,selected,flags,size)assert(not size or size.y>0);return clicked(label)end
function im.SetItemDefaultFocus()end
function im.ComboStr(_,ptr,items)
    assert(type(ptr)=='cdata' and type(items)=='string','ComboStr requires a NUL-separated string')
    return false
end
function im.CalcTextSize(text)return vec2(#text*7*im.GetFontSize()/15,im.GetFontSize())end
function im.InputText(_,ptr) assert(type(ptr)=='cdata');return false end
function im.Columns(count)assert(count>=1);im.columnCount=count end
function im.SetColumnWidth(index,width)assert(index>=0 and width>0)end
function im.NextColumn()assert(im.columnCount and im.columnCount>1)end
function im.SetClipboardText(text)im.clipboard=text end
function im.IsItemDeactivatedAfterEdit() return false end
function im.IsItemActive()return false end
function im.IsItemHovered()return false end
function im.StrCopy(dst,src) ffi.copy(dst,src);dst[#src]=0 end
local draw={}
for _,name in ipairs({'AddRectFilled','AddQuadFilled','AddRect','AddCircleFilled','AddCircle','AddText','AddTextFontPtr','AddImage','AddImageQuad','AddTriangleFilled',
    'AddLine','PushClipRect','PopClipRect'}) do
    draw[name]=function() im.drawCalls=im.drawCalls+1 end
end
draw.AddTextFontPtr=function(_,font,size,pos,color,text)im.drawCalls=im.drawCalls+1;im.drawTexts[#im.drawTexts+1]=text end
function im.GetWindowDrawList() return draw end
function im.GetBackgroundDrawList() return draw end
function im.CreateTextureFromFile() return ffi.cast('void*',1) end
function im.ReleaseTexture() end
function im.IsInitialized() return true end
return im

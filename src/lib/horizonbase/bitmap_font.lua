local data={fonts={pricedown=require 'horizonbase.pricedown_glyphs',gothic=require 'horizonbase.science_gothic_glyphs'}}
local M={};M.__index=M
function M.new(im,texture)
    return setmetatable({im=im,texture=texture},M)
end
function M:normalize(text,kind)
    text=tostring(text)
    if kind=='gothic' then text=text:upper() end
    return text
end
function M:width(text,height,kind)
    local font=data.fonts[kind];local scale=height/font.height;local width=0
    for ch in self:normalize(text,kind):gmatch('.')do
        local g=font.glyphs[ch] or font.glyphs[kind=='gothic' and '?' or '-']
        width=width+(ch==' ' and font.space or g and g[7] or font.space)*scale
    end
    return width
end
function M:draw(dl,text,x,y,height,kind,color,outline,slant)
    slant=slant or 0
    local tex=self.texture(data.fonts[kind].atlas or data.atlas)
    if not tex then return false end
    local im=self.im;local font=data.fonts[kind];local scale=height/font.height
    text=self:normalize(text,kind)
    local function pass(dx,dy,tint)
        local pen=x
        for ch in text:gmatch('.')do
            local g=font.glyphs[ch] or font.glyphs[kind=='gothic' and '?' or '-']
            if ch~=' ' and g then
                if slant==0 then
                    local function snap(value)return math.floor(value+.5)end
                    dl:AddImage(tex,im.ImVec2(snap(pen+dx),snap(y+dy)),im.ImVec2(snap(pen+dx+g[5]*scale),snap(y+dy+height)),
                        im.ImVec2(g[1],g[2]),im.ImVec2(g[3],g[4]),tint)
                else
                    local left,right=pen+dx,pen+dx+g[5]*scale;local top,bottom=y+dy,y+dy+height
                    local shear=height*slant
                    dl:AddImageQuad(tex,im.ImVec2(left+shear,top),im.ImVec2(right+shear,top),im.ImVec2(right,bottom),im.ImVec2(left,bottom),
                        im.ImVec2(g[1],g[2]),im.ImVec2(g[3],g[2]),im.ImVec2(g[3],g[4]),im.ImVec2(g[1],g[4]),tint)
                end
            end
            pen=pen+(ch==' ' and font.space or g and g[7] or font.space)*scale
        end
    end
    if outline and outline>0 then
        for _,v in ipairs({{-1,-1},{0,-1},{1,-1},{-1,0},{1,0},{-1,1},{0,1},{1,1}})do
            pass(v[1]*outline,v[2]*outline,im.U32(0,0,0,1))
        end
    end
    pass(0,0,color)
    return true
end
return M

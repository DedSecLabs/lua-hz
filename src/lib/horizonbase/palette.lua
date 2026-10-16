-- LuaHZ interface themes. Status, map and original GTA colors stay separate.
local M={default='graphite'}
M.themes={
    {id='graphite',name='Graphite + Ice Blue',colors={
        background='191f29',sidebar='121721',card='252d39',cardHover='2c4159',
        accent='78b9ff',accentStrong='4c9ced',accentHover='a3d0ff',
        text='edf2f8',muted='a9b6c7',border='354253',button='303c4d',
        buttonHover='3a4c63',buttonActive='304e70',selected='243c56',
        selectedHover='2d4b69',selectedActive='365d85',frame='141b25',
        frameHover='283547',frameActive='30445d',popup='161d27',
        toggleOff='495768',knob='f3f7fc'}},
    {id='midnight',name='Midnight + Periwinkle',colors={
        background='171d2a',sidebar='101520',card='232c3e',cardHover='313e5a',
        accent='9aabff',accentStrong='8194ee',accentHover='bbc6ff',
        text='edf0fa',muted='acb6ce',border='343f58',button='2d3850',
        buttonHover='3a4968',buttonActive='3c4d7c',selected='303b64',
        selectedHover='3b4978',selectedActive='485995',frame='121927',
        frameHover='28334b',frameActive='344362',popup='141a28',
        toggleOff='4b5670',knob='f5f5fc'}},
    {id='carbon',name='Carbon + Sea Glass',colors={
        background='202326',sidebar='15191c',card='2b3035',cardHover='35474b',
        accent='70cfce',accentStrong='48aaa9',accentHover='9be1df',
        text='ecf0f3',muted='acb7bf',border='3d474e',button='344149',
        buttonHover='40565b',buttonActive='345b60',selected='244749',
        selectedHover='2d595b',selectedActive='386c6d',frame='181e22',
        frameHover='2d3d43',frameActive='345055',popup='1b2226',
        toggleOff='515f66',knob='f2f8f7'}},
}
local byId={}
for _,theme in ipairs(M.themes)do byId[theme.id]=theme end
local function rgbaHex(hex)
    return {tonumber(hex:sub(1,2),16)/255,tonumber(hex:sub(3,4),16)/255,tonumber(hex:sub(5,6),16)/255,1}
end
function M.select(id)
    local theme=byId[id]or byId[M.default]
    if M.id==theme.id then return false end
    local c={transparent={0,0,0,0}}
    for token,hex in pairs(theme.colors)do c[token]=rgbaHex(hex)end
    M.id=theme.id;M.name=theme.name;M.colors=c
    M.style={
        WindowBg=c.background,ChildBg=c.transparent,Text=c.text,TextDisabled=c.muted,
        FrameBg=c.frame,FrameBgHovered=c.frameHover,FrameBgActive=c.frameActive,
        Button=c.button,ButtonHovered=c.buttonHover,ButtonActive=c.buttonActive,
        Header=c.selected,HeaderHovered=c.selectedHover,HeaderActive=c.selectedActive,
        CheckMark=c.accent,SliderGrab=c.accentStrong,SliderGrabActive=c.accentHover,
        Separator=c.border,PopupBg=c.popup,ScrollbarBg=c.transparent,ScrollbarGrab=c.toggleOff,
    }
    return true
end
local function rgba(name,alpha)
    local color=assert(M.colors[name],'Unknown LuaHZ palette token: '..tostring(name))
    return color[1],color[2],color[3],color[4]*(alpha or 1)
end
function M.vec4(im,name,alpha)return im.ImVec4(rgba(name,alpha))end
function M.u32(im,name,alpha)return im.U32(rgba(name,alpha))end
M.select(M.default)
return M

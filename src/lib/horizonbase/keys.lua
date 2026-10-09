-- Shared chord matching: exact modifiers prevent plain keys firing inside combos.
local bit=require 'bit'
local M={}
local groups={{1,17,162,163},{2,16,160,161},{4,18,164,165},{8,91,92}}
function M.isModifier(code)
    for _,group in ipairs(groups) do for i=2,#group do if code==group[i] then return true end end end
    return false
end
function M.modifiers(down)
    down=down or _G.isKeyDown or function()return false end
    local mask=0
    for _,group in ipairs(groups) do
        for i=2,#group do if down(group[i]) then mask=bit.bor(mask,group[1]);break end end
    end
    return mask
end
function M.matches(code,mods,key,current)
    return code~=0 and code==key and (mods or 0)==(current or M.modifiers())
end
function M.pressed(code,mods)
    return code~=0 and (mods or 0)==M.modifiers() and isKeyJustPressed(code)
end
return M

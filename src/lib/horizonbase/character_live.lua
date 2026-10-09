-- Values mirrored by the game client. RPG/account fields remain server snapshots.
local M={}
local function finite(n)return type(n)=='number' and n==n and math.abs(n)<1e11 end
function M.value(label,s)
    if not s or not s.ready then return nil end
    if label=='Health' and finite(s.health) then return tostring(math.floor(s.health+.5))end
    if label=='Armor' and finite(s.armour) then return tostring(math.floor(s.armour+.5))end
    if label=='Cash' and finite(s.money) then
        local n=tostring(math.floor(math.abs(s.money)))
        local formatted=n:reverse():gsub('(%d%d%d)','%1,'):reverse():gsub('^,','')
        return (s.money<0 and '-$' or '$')..formatted
    end
end
return M

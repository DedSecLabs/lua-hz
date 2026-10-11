-- Only these confirmed commands/nearby errors have fallback semantics.
local M={}
local function scope(command)
    local name=type(command)=='string' and command:lower():match('^/([a-z]+)%s*$')
    if name=='pvl' or name=='pvlock' then return 'personal' end
    if name=='gvl' then return 'group' end
end
function M.pair(first,second)
    local a,b=scope(first),scope(second)
    if a and b and a~=b then return {a,b}end
end
function M.nearbyFailure(text,kind)
    return kind=='personal' and text=='You are not near any vehicle that you own.' or
        kind=='group' and text=='You are not near any vehicle that your family owns.'
end
function M.success(text)
    if type(text)~='string' or #text>128 or text:find('[%c]') then return false end
    -- The observed server vehicle banner uses GTA color codes, then model + state.
    if not text:match('^~[gr]~') then return false end
    local name,state=text:gsub('~[%w]~',''):match('^(.+) (%a+)$')
    return name~=nil and #name<=64 and (state=='Locked' or state=='Unlocked')
end
return M

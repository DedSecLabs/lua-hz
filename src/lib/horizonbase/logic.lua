-- Pure behavior shared by the runtime and tests.
local M = {}
function M.clamp(n, lo, hi) return math.max(lo, math.min(hi, n)) end
function M.strip(text)
    return (text or ''):gsub('{%x%x%x%x%x%x}', ''):gsub('{%x%x%x%x%x%x%x%x}', ''):gsub('~[%a]~', '')
end
function M.price(text) return tonumber(((text or ''):gsub(',', ''))) end

-- These offer phrases and accept commands were observed in the installed release.
-- Restrict matching to the offer text; never accept a price-less or unknown offer.
function M.offer(text)
    text = M.strip(text)
    local cost = text:match('wants to repair your car for %$([%d,]+),')
    if cost then return {kind = 'repair', price = M.price(cost), command = '/accept repair'} end
    cost = text:match('wants to defend you for %$([%d,]+),')
    if cost then return {kind = 'lawyer', price = M.price(cost), command = '/accept defense'} end
    cost = text:match('you to have sex with them, for %$([%d,]+)%s')
    if cost then return {kind = 'whore', price = M.price(cost), command = '/accept sex'} end
    cost = text:match('wants to sell you %d+ gram.- for %$([%d,]+),')
    local accept = text:match('(/accept %l+)')
    if cost and accept then return {kind = 'drugs', price = M.price(cost), command = accept} end
    if text:find('is in need of a taxi driver at', 1, true) then
        return {kind = 'taxi', command = '/accept taxi'}
    end
end

function M.allowOffer(offer, prefs)
    if not offer or not prefs[offer.kind] then return false end
    if offer.kind == 'taxi' then return true end
    return offer.price ~= nil and offer.price >= 0 and offer.price <= (prefs[offer.kind .. 'Max'] or 0)
end

function M.normalizeName(name)
    return (name or ''):lower():gsub('_', ' '):gsub('^%s+', ''):gsub('%s+$', '')
end
function M.findResult(text)
    text = M.strip(text)
    local name, place = text:match('^(.-) has been last seen at (.+)%.$')
    if name then return {kind = 'found', name = name, place = place} end
    name, place = text:match("^SMS: Sources last seen (.+) go inside (.+), Sender: Unknown%.$")
    if name then return {kind = 'inside', name = name, place = place} end
    local person, cohort = text:match('^SMS: (.+) was last seen with (.+), Sender: Unknown%.$')
    if person then return {kind = 'cohort', name = person, cohort = cohort} end
    name = text:match("^SMS: I couldn't find any leads on (.+)'s cohorts%.?, Sender: Unknown%.$")
    if name then return {kind = 'no-cohort', name = name} end
end

function M.worldToMap(x, y, left, top, size)
    return left + (x + 3000) / 6000 * size, top + (3000 - y) / 6000 * size
end

function M.context(sample)
    if sample.swimming then return 'swimming' end
    if sample.vehicle and sample.boat then return 'inboat' end
    if sample.vehicle then return 'invehicle' end
    return 'onfoot'
end

function M.cruiseThrottle(currentMph, targetMph)
    return math.floor(M.clamp((targetMph - currentMph) * 34, 0, 255))
end

M.menuWidth=900
function M.interfaceScale(width,height,percent,baseWidth)
    local wanted=(height/1080)*(percent/100)
    local fit=math.min((width-32)/(baseWidth or 660),(height-32)/540)
    return math.min(fit,math.max(.5,wanted))
end

function M.hudLayout(width,height,prefs,baseHeight,baseWidth)
    baseWidth=baseWidth or 254
    local scale=math.max(.5,math.min(height/1080*(prefs.scale/100),
        (width-24)/baseWidth,(height-24)/baseHeight))
    local panelWidth,panelHeight=baseWidth*scale,baseHeight*scale
    local x=12+math.max(0,width-24-panelWidth)*(prefs.x/100)
    local y=12+math.max(0,height-24-panelHeight)*(prefs.y/100)
    return {x=x,y=y,width=panelWidth,height=panelHeight,scale=scale}
end

function M.displayHealth(raw,horizon)
    if horizon and raw>=5000000 and raw<=5001000 then return raw-5000000 end
    return raw
end

function M.ammoLabel(clip)
    return clip~=nil and ('Magazine: '..math.max(0,math.floor(clip))) or 'Magazine: --'
end

return M

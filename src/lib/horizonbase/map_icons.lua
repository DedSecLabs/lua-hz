-- Standard SA-MP sprite names, not Horizon-specific location descriptions.
-- https://open.mp/docs/scripting/resources/mapicons
local bit=require 'bit'
local M={}
local names={
    [0]='Colored marker','White square','Player position','Player (menu map)','North',
    'Air yard','Ammu-Nation','Barber','Big Smoke','Boat yard','Burger Shot','Quarry',
    'Catalina','Cesar',"Cluckin' Bell",'Carl Johnson','C.R.A.S.H.','Diner','Emmet',
    'Enemy attack','Fire','Girlfriend','Hospital','Loco','Madd Dogg',"Caligula's",
    'MC Strap','Mod garage','OG Loc','Pizza','Police','Property for sale',
    'Property not for sale','Race','Ryder','Save house','School','Mystery','Sweet',
    'Tattoo','The Truth','Waypoint',"Toreno's ranch",'Triads','Triads casino',
    'Clothes shop','Woozie','Zero','Disco date','Drinking date','Restaurant',
    'Trucking','Robbery','Race tournament','Gym','Car impound','Light',
    'Nearest air strip','Varrios Los Aztecas','Ballas','Los Santos Vagos',
    'San Fierro Rifa','Grove Street Families',"Pay 'n' Spray"
}

function M.name(kind) return names[kind] or 'Unknown sprite' end

-- GTA's radar sprite order; this HD pack names the Loco skull Jizzy.png.
-- https://github.com/gta-reversed/gta-reversed/blob/master/source/game_sa/Radar.cpp
local files={
    'radar_centre','arrow','radar_north','radar_airYard','radar_ammugun',
    'radar_barbers','radar_BIGSMOKE','radar_boatyard','radar_burgerShot',
    'radar_bulldozer','radar_CATALINAPINK','radar_CESARVIAPANDO','radar_chicken',
    'radar_CJ','radar_CRASH1','radar_diner','radar_emmetGun','radar_enemyAttack',
    'radar_fire','radar_girlfriend','radar_hostpital','Jizzy','radar_MADDOG',
    'radar_mafiaCasino','radar_MCSTRAP','radar_modGarage','radar_OGLOC',
    'radar_pizza','radar_police','radar_propertyG','radar_propertyR','radar_race',
    'radar_RYDER','radar_saveGame','radar_school','radar_qmark','radar_SWEET',
    'radar_tattoo','radar_THETRUTH','radar_waypoint','radar_TorenoRanch',
    'radar_triads','radar_triadsCasino','radar_tshirt','radar_WOOZIE','radar_ZERO',
    'radar_dateDisco','radar_dateDrink','radar_dateFood','radar_truck','radar_cash',
    'radar_Flag','radar_gym','radar_impound','radar_light','radar_runway',
    'radar_gangB','radar_gangP','radar_gangY','radar_gangN','radar_gangG','radar_spray'
}
function M.file(kind)
    local file=type(kind)=='number' and files[kind-1]
    return file and file..'.png' or nil
end

function M.rgba(color,opacity)
    color=color or 0
    return bit.band(bit.rshift(color,24),255)/255,bit.band(bit.rshift(color,16),255)/255,
        bit.band(bit.rshift(color,8),255)/255,bit.band(color,255)/255*opacity
end

function M.diagnostics(icons)
    local ids={}
    for id in pairs(icons) do ids[#ids+1]=id end
    table.sort(ids)
    local lines={('[Map icons] active=%d; names describe standard sprites, not server locations'):format(#ids)}
    if #ids==0 then
        lines[#lines+1]='[Map icons] No markers captured. Start LuaHZ before connecting to receive initial server icons.'
    end
    for _,id in ipairs(ids) do
        local icon=icons[id];local p=icon.position
        lines[#lines+1]=('[Map icon] id=%s type=%s sprite=%s rgba=0x%s style=%s x=%.2f y=%.2f z=%.2f'):format(
            tostring(id),tostring(icon.kind),M.name(icon.kind),bit.tohex(icon.color or 0,8):upper(),
            tostring(icon.style),p.x,p.y,p.z or 0)
    end
    return lines
end
return M

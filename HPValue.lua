_addon.name = 'HPValue'
_addon.author = 'Otamarai'
_addon.version = '0.1'

require('sets')
require('functions')
texts = require('texts')
packets = require('packets')
zones = require('resources').zones
spellTable = require('SpellTable')

areaMobs = {}
delay = 0.2
scanDelay = 3
scanTime = 0
nextTime = os.clock()


hp = texts.new('${HPC|100}/${HPT|100}', {
    pos = {
        x = -76,
    },
    bg = {
        visible = true,
    },
    flags = {
        right = true,
        bottom = true,
        bold = true,
        draggable = false,
        italic = true,
    },
    text = {
        size = 10,
        alpha = 185,
        red = 115,
        green = 166,
        blue = 213,
    },
})

hp_y_pos = {}
for i = 1, 6 do
    hp_y_pos[i] = -95 - 20 * i
end


invalidZones = S{
  "Southern San d'Oria", "Northern San d'Oria", "Port San d'Oria", "Chateau d'Oraguille",
  "Bastok Mines", "Bastok Markets", "Port Bastok", "Metalworks",
  "Windurst Waters", "Windurst Walls", "Port Windurst", "Windurst Woods",
  "Ru'Lude Gardens", "Upper Jeuno", "Lower Jeuno", "Port Jeuno",
  --[["Al Zahbi", --]]"Aht Urhgan Whitegate",
  "Selbina", "Mhaura", "Tavnazian Safehold", "Nashmau", "Rabao", "Kazham", "Norg",
}



--Check the listed ID against the party member's IDs(and their pets)
function checkIDInParty(checkID)
	local party = windower.ffxi.get_party()
	for i, v in pairs(party) do
		if string.match(i, 'p[0-5]') and v.mob then
			if v.mob.id == checkID or (v.mob.pet_index and windower.ffxi.get_mob_by_index(v.mob.pet_index) and windower.ffxi.get_mob_by_index(v.mob.pet_index).id == checkID) then
				return true
			end
		end
	end
	return false
end


-- HP calculations
windower.register_event('prerender', function()
	local mob = windower.ffxi.get_mob_by_target('st') or windower.ffxi.get_mob_by_target('t')
	local info = windower.ffxi.get_info()
	local curTime = os.clock()
	if nextTime + delay <= curTime then
		nextTime = curTime
		delay = 0.2
		for i, v in pairs(windower.ffxi.get_mob_array()) do
			local findLevel = false
			if not areaMobs[v.name] then
				areaMobs[v.name] = {}
			end
			if not areaMobs[v.id] then
				areaMobs[v.id] = {}
			end
			if areaMobs[v.id] and (not areaMobs[v.id].CurrentLevel or areaMobs[v.id].CurrentLevel == 0) and windower.ffxi.get_mob_by_id(v.id) and windower.ffxi.get_mob_by_id(v.id).valid_target and windower.ffxi.get_mob_by_id(v.id).spawn_type == 16 and scanTime + scanDelay <= curTime and not invalidZones:contains(zones[info.zone].en) then
				packet = packets.new('outgoing', 0x0F4, {--Widescan
					['Flags'] = 1,
					['_unknown1'] = 0,
					['_unknown2'] = 0,
				})
				packets.inject(packet)
				if mob and mob.id == v.id then
					hp:hide()
				end
				scanTime = os.clock()
				return
			end
			if areaMobs[v.id] and areaMobs[v.id].CurrentLevel and areaMobs[v.id].CurrentLevel ~= 0 then
				if not areaMobs[v.id].DT then
					areaMobs[v.id].DT = 0
				end
				if not areaMobs[v.id].HPP then
					areaMobs[v.id].HPP = v.hpp
				end
				if mob and mob.id == v.id and (v.hpp == 0 or v.status > 1) then
					areaMobs[v.id].HPP = 100
					areaMobs[v.id].DT = 0
					areaMobs[v.id].HPC = 0
				elseif not mob and (v.hpp == 0 or v.status > 1) then
					areaMobs[v.id].HPP = 100
					areaMobs[v.id].DT = 0
					areaMobs[v.id].HPC = areaMobs[v.id].HPT
				elseif v.valid_target and checkIDInParty(v.claim_id) and v.is_npc and v.status == 1 and v.spawn_type == 16 then
					if v.hpp == 100 then
						areaMobs[v.id].HPP = 100
						areaMobs[v.id].DT = 0
					end
					if v.hpp ~= 100 and areaMobs[v.id].DT ~= 0 and areaMobs[v.id].HPP ~= v.hpp then
						areaMobs[v.id].HPP = v.hpp
						areaMobs[v.id].HPT = math.floor((areaMobs[v.id].DT)/((100-v.hpp)/100))
						areaMobs[v.id].HPC = math.floor(areaMobs[v.id].HPT*((v.hpp)/100))
						areaMobs[v.name].LevelInfo[areaMobs[v.id].CurrentLevel].HPT = areaMobs[v.id].HPT
					end
				end
			end
		end
		--If we're targetting an actual mob
		if mob and mob.spawn_type == 16 then
			local party_info = windower.ffxi.get_party_info()
			-- Adjust position for party member count
			hp:pos_y(hp_y_pos[party_info.party1_count])
			if areaMobs[mob.id] and areaMobs[mob.id].CurrentLevel and areaMobs[mob.id].CurrentLevel ~= 0 and areaMobs[mob.name].LevelInfo[areaMobs[mob.id].CurrentLevel].HPT  then
				local getHPT = areaMobs[mob.name].LevelInfo[areaMobs[mob.id].CurrentLevel].HPT
				hp.HPT = getHPT
				hp.HPC = math.floor(getHPT*((mob.hpp)/100))
			else
				hp.HPC = mob.hpp
				hp.HPT = nil
			end
			hp:show()
		else
			hp:hide()
		end
	end
	
end)



--Record the damage on our target
windower.register_event('action', function(act)
	local player = windower.ffxi.get_player()
	if act.targets[1] and act.targets[1].id and act.targets[1].id ~= player.id and not checkIDInParty(act.targets[1].id) and (checkIDInParty(windower.ffxi.get_mob_by_id(act.targets[1].id).claim_id) or checkIDInParty(act.actor_id)) then
		if act.category == 1 or act.category == 2 or act.category == 3 or act.category == 4 or act.category == 6 then
			local damageTaken = 0
			for i = 1, #act.targets[1].actions do
				damageTaken = damageTaken + act.targets[1].actions[i].param
				if category == 3 and act.targets[1].actions[1].add_effect_param and act.targets[1].actions[1].add_effect_param > 0 then
					damageTaken = act.targets[1].actions[i].add_effect_param
				end
			end

			--Check to see if the mob is actually dead
			local checkDMG = areaMobs[act.targets[1].id].DT + damageTaken
			if areaMobs[act.targets[1].id].HPT and areaMobs[act.targets[1].id].HPT < checkDMG then
				areaMobs[act.targets[1].id].DT = areaMobs[act.targets[1].id].DT + areaMobs[act.targets[1].id].HPC
			else
				areaMobs[act.targets[1].id].DT = checkDMG
			end
			
		end
	elseif act.actor_id and checkIDInParty(windower.ffxi.get_mob_by_id(act.actor_id).claim_id) and windower.ffxi.get_mob_by_id(act.actor_id).spawn_type == 16 then
		if act.category == 4 and spellTable['Heals']:contains(tostring(act.param)) then
			local healingTaken = 0
			healingTaken = healingTaken + act.targets[1].actions[1].param
			areaMobs[act.actor_id].DT = areaMobs[act.actor_id].DT - healingTaken
		elseif act.category == 11 and spellTable['TPMoves']:contains(tostring(act.param)) then
			local healingTaken = 0
			healingTaken = healingTaken + act.targets[1].actions[1].param
			areaMobs[act.actor_id].DT = areaMobs[act.actor_id].DT - healingTaken
		end
	end
end)


--Wipe the mob list on zone change to prevent any eventual lag
windower.register_event('zone change', function(new, old)
	areaMobs = {}
end)



windower.register_event('incoming chunk', function(id, original, modified, injected, blocked)
    --Widescan
	if id == 0x0F4 then
        local packet = packets.parse('incoming', original)
        local mob = windower.ffxi.get_mob_by_index(packet['Index'])
		if mob then
			if not areaMobs[mob.name] then
				areaMobs[mob.name] = {}
			end
			if not areaMobs[mob.name].LevelInfo then
				areaMobs[mob.name].LevelInfo = {}
			end
			areaMobs[mob.id].CurrentLevel = tonumber(packet['Level'])
			local findLevel = areaMobs[mob.name].LevelInfo[tonumber(packet['Level'])]
			if not findLevel then
				areaMobs[mob.name].LevelInfo[tonumber(packet['Level'])] = {}
			end
		end
    end
end)












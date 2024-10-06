_addon.name = 'HPValue'
_addon.author = 'Otamarai'
_addon.version = '0.1'

require('sets')
require('functions')
texts = require('texts')
packets = require('packets')
zones = require('resources').zones

areamobs = {}
delay = 0.2
scanDelay = 3
nextTime = os.clock()


--Pulled from TParty
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
			if mob and areamobs[v.id] and (v.hpp == 0 or v.status > 1) then
				if areamobs[v.id].HPP ~= 100 then
					areamobs[v.id].HPP = 100
					areamobs[v.id].DT = 0
					areamobs[v.id].HPC = 0
				end
			elseif not mob and areamobs[v.id] and (v.hpp == 0 or v.status > 1) then
				if areamobs[v.id].HPC ~= nil then
					areamobs[v.id].HPP = 100
					areamobs[v.id].DT = 0
					areamobs[v.id].HPT = nil
					areamobs[v.id].HPC = nil
				end
			elseif v.valid_target and checkIDInParty(v.claim_id) and v.is_npc and v.status == 1 and v.spawn_type == 16 then
				if not areamobs[v.id] then
					areamobs[v.id] = {}
					areamobs[v.id].DT = 0
					areamobs[v.id].HPP = v.hpp
				end
				
				if areamobs[v.id] and v.hpp == 100 then
					areamobs[v.id].HPP = v.hpp
					areamobs[v.id].DT = 0
					areamobs[v.id].HPT = nil
					areamobs[v.id].HPC = nil
				end
				if v.hpp ~= 100 and areamobs[v.id].DT ~= 0 and areamobs[v.id].HPP ~= v.hpp then
					areamobs[v.id].HPP = v.hpp
					areamobs[v.id].HPT = math.floor((areamobs[v.id].DT)/((100-v.hpp)/100))
					areamobs[v.id].HPC = math.floor(areamobs[v.id].HPT*((v.hpp)/100))
				end
			end
			
		end
		if mob then
			local party_info = windower.ffxi.get_party_info()
			-- Adjust position for party member count
			hp:pos_y(hp_y_pos[party_info.party1_count])
			if not areamobs[mob.id] then
				hp.HPC = mob.hpp
				hp.HPT = nil
			elseif areamobs[mob.id] and areamobs[mob.id].DT == 0 and mob.hpp > 0 then
				hp.HPC = mob.hpp
				hp.HPT = nil
			else
				hp:update(areamobs[mob.id])
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
	if act.targets[1] and act.targets[1].id and act.targets[1].id ~= player.id and (checkIDInParty(windower.ffxi.get_mob_by_id(act.targets[1].id).claim_id) or checkIDInParty(act.actor_id)) then
		if act.category == 1 or act.category == 2 or act.category == 3 or act.category == 4 or act.category == 6 then
			local damageTaken = 0
			for i = 1, #act.targets[1].actions do
				damageTaken = damageTaken + act.targets[1].actions[i].param
				if category == 3 and act.targets[1].actions[1].add_effect_param and act.targets[1].actions[1].add_effect_param > 0 then
				damageTaken = act.targets[1].actions[i].add_effect_param
				end
			end
			if not areamobs[act.targets[1].id] then
				areamobs[act.targets[1].id] = {}
				areamobs[act.targets[1].id].DT = 0
			end
			--Check to see if the mob is actually dead
			local checkDMG = areamobs[act.targets[1].id].DT + damageTaken
			if areamobs[act.targets[1].id].HPT and areamobs[act.targets[1].id].HPT < checkDMG then
				areamobs[act.targets[1].id].DT = areamobs[act.targets[1].id].DT + areamobs[act.targets[1].id].HPC
			else
				areamobs[act.targets[1].id].DT = checkDMG
			end
			
		end
	end
end)


--Wipe the mob list on zone change to prevent any eventual lag
windower.register_event('zone change', function(new, old)
	areamobs = {}
end)


--[[
windower.register_event('incoming chunk', function(id, original, modified, injected, blocked)
    --Widescan
	if id == 0x0F4 then
        local packet = packets.parse('incoming', original)
        local mob = windower.ffxi.get_mob_by_index(packet['Index'])
		if mob and areamobs[mob.id] then
			areamobs[mob.id].CurrentLevel = packet['Level']
		end
    end
end)

]]










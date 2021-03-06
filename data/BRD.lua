-------------------------------------------------------------------------------------------------------------------
-- Setup functions for this job.  Generally should not be modified.
-------------------------------------------------------------------------------------------------------------------

--[[
    Custom commands:

    ExtraSongsMode may take one of three values: None, Dummy, FullLength

    You can set these via the standard 'set' and 'cycle' self-commands.  EG:
    gs c cycle ExtraSongsMode
    gs c set ExtraSongsMode Dummy

    The Dummy state will equip the bonus song instrument and ensure non-duration gear is equipped.
    The FullLength state will simply equip the bonus song instrument on top of standard gear.


    Simple macro to cast a dummy Daurdabla song:
    /console gs c set ExtraSongsMode Dummy
    /ma "Mage's Ballad" <me>

    To use a Terpander rather than Daurdabla, set the info.ExtraSongInstrument variable to
    'Terpander', and info.ExtraSongs to 1.
--]]

-- Initialization function for this job file.
function get_sets()
    -- Load and initialize the include file.
    include('Sel-Include.lua')
end

-- Setup vars that are user-independent.  state.Buff vars initialized here will automatically be tracked.
function job_setup()

    state.ExtraSongsMode = M{['description']='Extra Songs','None','Dummy','DummyLock','FullLength','FullLengthLock'}

	state.Buff['Aftermath: Lv.3'] = buffactive['Aftermath: Lv.3'] or false
    state.Buff['Pianissimo'] = buffactive['Pianissimo'] or false
	state.Buff['Nightingale'] = buffactive['Nightingale'] or false
	state.RecoverMode = M('35%', '60%', 'Always', 'Never')

	autows = "Rudra's Storm"
	autofood = 'Pear Crepe'
	
	state.AutoSongMode = M(false, 'Auto Song Mode')

	update_melee_groups()
	init_job_states({"Capacity","AutoRuneMode","AutoTrustMode","AutoNukeMode","AutoWSMode","AutoShadowMode","AutoFoodMode","AutoStunMode","AutoDefenseMode","AutoSongMode",},{"AutoBuffMode","AutoSambaMode","Weapons","OffenseMode","WeaponskillMode","IdleMode","Passive","RuneElement","ExtraSongsMode","CastingMode","TreasureMode",})
end

-------------------------------------------------------------------------------------------------------------------
-- Job-specific hooks for standard casting events.
-------------------------------------------------------------------------------------------------------------------
-- Set eventArgs.handled to true if we don't want any automatic gear equipping to be done.
-- Set eventArgs.useMidcastGear to true if we want midcast gear equipped on precast.

-- Set eventArgs.handled to true if we don't want any automatic target handling to be done.

function job_filtered_action(spell, eventArgs)

end

function job_pretarget(spell, spellMap, eventArgs)
    if spell.type == 'BardSong' and not spell.targets.Enemy then
		if state.Buff['Pianissimo'] and spell.target.raw == '<t>' and (player.target.type == 'NONE' or spell.target.type == 'MONSTER') then
			eventArgs.cancel = true
			windower.chat.input('/ma "'..spell.name..'" <stpt>')
		elseif spell.target.raw == '<t>' and (player.target.type == 'NONE' or player.target.type == "MONSTER") and not state.Buff['Pianissimo'] then
			change_target('<me>')
			return
		end
    end
end

function job_precast(spell, spellMap, eventArgs)
	if spell.action_type == 'Magic' then
		if not sets.precast.FC[spell.english] and (spell.type == 'BardSong' and spell.targets.Enemy) then
			classes.CustomClass = 'SongDebuff'
		end
	end
end

function job_filter_precast(spell, spellMap, eventArgs)
    if spell.type == 'BardSong' and not spell.targets.Enemy then
		local spell_recasts = windower.ffxi.get_spell_recasts()
		
        -- Auto-Pianissimo
        if ((spell.target.type == 'PLAYER' and not spell.target.charmed) or (spell.target.type == 'NPC')) and spell.target.in_party and not state.Buff['Pianissimo'] then
            if spell_recasts[spell.recast_id] < 1.5 then
                send_command('@input /ja "Pianissimo" <me>; wait 1.1; input /ma "'..spell.name..'" '..spell.target.name)
                eventArgs.cancel = true
            end
        end
    end
end

-- Set eventArgs.handled to true if we don't want any automatic gear equipping to be done.
function job_midcast(spell, spellMap, eventArgs)
    if spell.action_type == 'Magic' then
        if spell.type == 'BardSong' then
            -- layer general gear on first, then let default handler add song-specific gear.
            local generalClass = get_song_class(spell)
			if generalClass and sets.midcast[generalClass] then
				if sets.midcast[generalClass][state.CastingMode.value] then
					equip(sets.midcast[generalClass][state.CastingMode.value])
				else
					equip(sets.midcast[generalClass])
				end
            end
        end
    end
end

function job_post_precast(spell, spellMap, eventArgs)
	if spell.type == 'BardSong' then
	
		if state.Buff['Nightingale'] then
		
			-- Replicate midcast in precast for nightingale including layering.
            local generalClass = get_song_class(spell)
			if generalClass and sets.midcast[generalClass] then
				if sets.midcast[generalClass][state.CastingMode.value] then
					equip(sets.midcast[generalClass][state.CastingMode.value])
				else 
					equip(sets.midcast[generalClass])
				end
            end

			if sets.midcast[spell.english] then
				if sets.midcast[spell.english][state.CastingMode.value] then
					equip(sets.midcast[spell.english][state.CastingMode.value])
				else
					equip(sets.midcast[spell.english])
				end
			elseif sets.midcast[get_spell_map(spell, default_spell_map)] then
				if sets.midcast[get_spell_map(spell, default_spell_map)][state.CastingMode.Value]
					then equip(sets.midcast[get_spell_map(spell, default_spell_map)][state.CastingMode.Value])
				else
					equip(sets.midcast[get_spell_map(spell, default_spell_map)])
				end
			end
			
			if not spell.targets.Enemy and state.ExtraSongsMode.value:contains('FullLength') then
				equip(sets.midcast.Daurdabla)
			end
		
		end

	elseif spell.type == 'WeaponSkill' then
		local WSset = standardize_set(get_precast_set(spell, spellMap))
		local wsacc = check_ws_acc()
		
		if (WSset.ear1 == "Moonshade Earring" or WSset.ear2 == "Moonshade Earring") then
			-- Replace Moonshade Earring if we're at cap TP
			if get_effective_player_tp(spell, WSset) > 3200 then
				if wsacc:contains('Acc') and not buffactive['Sneak Attack'] and sets.AccMaxTP then
					equip(sets.AccMaxTP[spell.english] or sets.AccMaxTP)
				elseif sets.MaxTP then
					equip(sets.MaxTP[spell.english] or sets.MaxTP)
				else
				end
			end
		end
	end
end

function job_post_midcast(spell, spellMap, eventArgs)
    if spell.type == 'BardSong' then
		if spell.targets.Enemy then
			if sets.midcast[spell.english] then
				if sets.midcast[spell.english][state.CastingMode.value] then
					equip(sets.midcast[spell.english][state.CastingMode.value])
				else
					equip(sets.midcast[spell.english])
				end
			elseif sets.midcast[spellMap] then
				if sets.midcast[spellMap][state.CastingMode.value] then
					equip(sets.midcast[spellMap][state.CastingMode.value])
				else
					equip(sets.midcast[spellMap])
				end
			end
			
			if can_dual_wield and sets.midcast.SongDebuff.DW then
				equip(sets.midcast.SongDebuff.DW)
			end
		else
			if can_dual_wield and sets.midcast.SongEffect.DW then
				equip(sets.midcast.SongEffect.DW)
			end
		end
		
		if state.ExtraSongsMode.value:contains('FullLength') then
            equip(sets.midcast.Daurdabla)
        end

        if not state.ExtraSongsMode.value:contains('Lock') then
			state.ExtraSongsMode:reset()
		end

		if state.DisplayMode.value then update_job_states()	end

    elseif spell.skill == 'Elemental Magic' and default_spell_map ~= 'ElementalEnfeeble' then
        if state.MagicBurstMode.value ~= 'Off' then equip(sets.MagicBurst) end
		if spell.element == world.weather_element or spell.element == world.day_element then
			if state.CastingMode.value == 'Fodder' then
				if spell.element == world.day_element then
					if item_available('Zodiac Ring') then
						sets.ZodiacRing = {ring2="Zodiac Ring"}
						equip(sets.ZodiacRing)
					end
				end
			end
		end

		if spell.element == 'Wind' and sets.WindNuke then
			equip(sets.WindNuke)
		elseif spell.element == 'Ice' and sets.IceNuke then
			equip(sets.IceNuke)
		end

		if state.RecoverMode.value ~= 'Never' and (state.RecoverMode.value == 'Always' or tonumber(state.RecoverMode.value:sub(1, -2)) > player.mpp) then
			equip(sets.RecoverMP)
		end
    end
end

-- Set eventArgs.handled to true if we don't want automatic gear equipping to be done.
function job_aftercast(spell, spellMap, eventArgs)
	if spell.skill == 'Elemental Magic' and state.MagicBurstMode.value == 'Single' then
		state.MagicBurstMode:reset()
		if state.DisplayMode.value then update_job_states()	end
    end
end

function job_buff_change(buff, gain)
	update_melee_groups()
end

function job_get_spell_map(spell, default_spell_map)

	if  default_spell_map == 'Cure' or default_spell_map == 'Curaga'  then
		if world.weather_element == 'Light' then
                return 'LightWeatherCure'
		elseif world.day_element == 'Light' then
                return 'LightDayCure'
        end

	elseif spell.skill == "Enfeebling Magic" then
		if spell.english:startswith('Dia') then
			return "Dia"
		elseif spell.type == "WhiteMagic" or spell.english:startswith('Frazzle') or spell.english:startswith('Distract') then
			return 'MndEnfeebles'
		else
			return 'IntEnfeebles'
		end
	end
end

-------------------------------------------------------------------------------------------------------------------
-- Job-specific hooks for non-casting events.
-------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------
-- User code that supplements standard library decisions.
-------------------------------------------------------------------------------------------------------------------

-- Called by the 'update' self-command.
function job_update(cmdParams, eventArgs)
	update_melee_groups()
end


-- Modify the default idle set after it was constructed.
function job_customize_idle_set(idleSet)
    if buffactive['Sublimation: Activated'] then
        if (state.IdleMode.value == 'Normal' or state.IdleMode.value:contains('Sphere')) and sets.buff.Sublimation then
            idleSet = set_combine(idleSet, sets.buff.Sublimation)
        elseif state.IdleMode.value:contains('DT') and sets.buff.DTSublimation then
            idleSet = set_combine(idleSet, sets.buff.DTSublimation)
        end
    end

    if player.mpp < 51 and (state.IdleMode.value == 'Normal' or state.IdleMode.value:contains('Sphere')) then
		if sets.latent_refresh then
			idleSet = set_combine(idleSet, sets.latent_refresh)
		end
		
		local available_ws = S(windower.ffxi.get_abilities().weapon_skills)
		if available_ws:contains(176) and sets.latent_refresh_grip then
			idleSet = set_combine(idleSet, sets.latent_refresh_grip)
		end
    end

    return idleSet
end


-- Function to display the current relevant user state when doing an update.
function display_current_job_state(eventArgs)
    display_current_caster_state()
    eventArgs.handled = true
end

-------------------------------------------------------------------------------------------------------------------
-- Utility functions specific to this job.
-------------------------------------------------------------------------------------------------------------------

-- Determine the custom class to use for the given song.
function get_song_class(spell)
    -- Can't use spell.targets:contains() because this is being pulled from resources
    if spell.targets.Enemy then
		return 'SongDebuff'
    elseif state.ExtraSongsMode.value:contains('Dummy') then
        return 'DaurdablaDummy'
    else
        return 'SongEffect'
    end
end

-- Examine equipment to determine what our current TP weapon is.
function update_melee_groups()
	if player.equipment.main then
		classes.CustomMeleeGroups:clear()

		if player.equipment.main == "Carnwenhan" and state.Buff['Aftermath: Lv.3'] then
				classes.CustomMeleeGroups:append('AM')
		end
	end
end

    -- Allow jobs to override this code
function job_self_command(commandArgs, eventArgs)

end

function job_tick()
	if check_song() then return true end
	if check_buff() then return true end
	if check_buffup() then return true end
	return false
end

function check_song()
	if state.AutoSongMode.value then
		if not buffactive.march then
			windower.chat.input('/ma "Honor March" <me>')
			tickdelay = os.clock() + 2
			return true
		elseif not buffactive.minuet then
			windower.chat.input('/ma "Valor Minuet V" <me>')
			tickdelay = os.clock() + 2
			return true
		elseif not buffactive.madrigal then
			windower.send_command('gs c set ExtraSongsMode FullLength;input /ma "Blade Madrigal" <me>')
			tickdelay = os.clock() + 2
			return true
		else
			return false
		end
	else
		return false
	end
end

function check_buff()
	if state.AutoBuffMode.value ~= 'Off' and not areas.Cities:contains(world.area) then
		local spell_recasts = windower.ffxi.get_spell_recasts()
		for i in pairs(buff_spell_lists[state.AutoBuffMode.Value]) do
			if not buffactive[buff_spell_lists[state.AutoBuffMode.Value][i].Buff] and (buff_spell_lists[state.AutoBuffMode.Value][i].When == 'Always' or (buff_spell_lists[state.AutoBuffMode.Value][i].When == 'Combat' and (player.in_combat or being_attacked)) or (buff_spell_lists[state.AutoBuffMode.Value][i].When == 'Engaged' and player.status == 'Engaged') or (buff_spell_lists[state.AutoBuffMode.Value][i].When == 'Idle' and player.status == 'Idle') or (buff_spell_lists[state.AutoBuffMode.Value][i].When == 'OutOfCombat' and not (player.in_combat or being_attacked))) and spell_recasts[buff_spell_lists[state.AutoBuffMode.Value][i].SpellID] < spell_latency and silent_can_use(buff_spell_lists[state.AutoBuffMode.Value][i].SpellID) then
				windower.chat.input('/ma "'..buff_spell_lists[state.AutoBuffMode.Value][i].Name..'" <me>')
				tickdelay = os.clock() + 2
				return true
			end
		end
	else
		return false
	end
end

function check_buffup()
	if buffup ~= '' then
		local needsbuff = false
		for i in pairs(buff_spell_lists[buffup]) do
			if not buffactive[buff_spell_lists[buffup][i].Buff] and silent_can_use(buff_spell_lists[buffup][i].SpellID) then
				needsbuff = true
				break
			end
		end
	
		if not needsbuff then
			add_to_chat(217, 'All '..buffup..' buffs are up!')
			buffup = ''
			return false
		end
		
		local spell_recasts = windower.ffxi.get_spell_recasts()
		
		for i in pairs(buff_spell_lists[buffup]) do
			if not buffactive[buff_spell_lists[buffup][i].Buff] and silent_can_use(buff_spell_lists[buffup][i].SpellID) and spell_recasts[buff_spell_lists[buffup][i].SpellID] < spell_latency then
				windower.chat.input('/ma "'..buff_spell_lists[buffup][i].Name..'" <me>')
				tickdelay = os.clock() + 2
				return true
			end
		end
		
		return false
	else
		return false
	end
end

buff_spell_lists = {
	Auto = {--Options for When are: Always, Engaged, Idle, OutOfCombat, Combat
		{Name='Refresh',			Buff='Refresh',			SpellID=109,	When='Idle'},
		{Name='Phalanx',			Buff='Phalanx',			SpellID=106,	When='Idle'},
		{Name='Stoneskin',			Buff='Stoneskin',		SpellID=54,		When='Idle'},
		{Name='Blink',				Buff='Blink',			SpellID=53,		When='Idle'},
	},
	Default = {
		{Name='Refresh',			Buff='Refresh',			SpellID=109,	Reapply=false},
		{Name='Phalanx',			Buff='Phalanx',			SpellID=106,	Reapply=false},
		{Name='Stoneskin',			Buff='Stoneskin',		SpellID=54,		Reapply=false},
		{Name='Blink',				Buff='Blink',			SpellID=53,		Reapply=false},
	},
}

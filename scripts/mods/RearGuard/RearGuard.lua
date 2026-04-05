-- Author: ImperialSkoom

local mod = get_mod("RearGuard")

local BACKSTAB_MELEE_EVENTS = {
	["wwise/events/player/play_backstab_indicator_melee"] = true,
	["wwise/events/player/play_backstab_indicator_melee_elite"] = true,
}

local block_start_t      = 0
local block_until_t      = 0
local next_trigger_t     = 0
local dodge_start_t      = 0
local dodge_until_t      = 0
local parry_press_queued = false

local DEFAULT_BLOCK_DELAY           = 0.10
local DEFAULT_BLOCK_DURATION        = 0.60
local DEFAULT_DODGE_DELAY           = 0.10
local DEFAULT_DODGE_QUEUE_DURATION  = 0.20
local DEFAULT_TRIGGER_COOLDOWN      = 0.1

local setting_enabled = true

local MINIGAME_VIEW_NAMES = {
	"minigame_decode_search_view",
	"scanner_display_view",
}

local SPRINT_INPUT_ACTIONS = {
	sprint = true,
	sprinting = true,
	hold_to_sprint = true,
}

local cached_sprint_input = {
	sprint = false,
	sprinting = false,
	hold_to_sprint = false,
}

local sprint_utility_active = false

-- Cached combat-sword pattern (avoid rebuilding on every check)
local COMBAT_SWORD_PATTERNS = {
	"^combatsword_p1_m%d+$",
	"^combatsword_p3_m%d+$",
}

-- Helpers

local function main_time()
	return Managers and Managers.time and Managers.time:time("main") or 0
end

local function local_player_unit()
	local mgr = Managers and Managers.player
	local p   = mgr and mgr:local_player_safe(1)
	return p and p.player_unit
end

-- Returns weapon_extension, inventory, wielded_weapon -- avoids re-traversal
local function get_weapon_info(player_unit)
	local ext = player_unit and ScriptUnit.has_extension(player_unit, "weapon_system")
	if not ext then return nil, nil, nil end
	local inv = ext._inventory_component
	local ww  = ext:_wielded_weapon(inv, ext._weapons)
	return ext, inv, ww
end

local function refresh_enabled_setting()
	local stored_value = mod:get("enable_mod")
	setting_enabled = stored_value == nil and true or stored_value
	return setting_enabled
end

local function reset_response_state()
	block_start_t = 0
	block_until_t = 0
	next_trigger_t = 0
	dodge_start_t = 0
	dodge_until_t = 0
	parry_press_queued = false
end

local function numeric_setting(setting_id, default_value, min_value)
	local value = tonumber(mod:get(setting_id))
	if not value then return default_value end
	if min_value and value < min_value then return min_value end
	return value
end

local function boolean_setting(setting_id, default_value)
	local value = mod:get(setting_id)
	if value == nil then return default_value end
	return value == true
end

local function block_delay()          return numeric_setting("block_delay", DEFAULT_BLOCK_DELAY, 0) end
local function block_duration()       return numeric_setting("block_duration", DEFAULT_BLOCK_DURATION, 0) end
local function dodge_delay()          return numeric_setting("dodge_delay", DEFAULT_DODGE_DELAY, 0) end
local function dodge_queue_duration() return numeric_setting("dodge_queue_duration", DEFAULT_DODGE_QUEUE_DURATION, 0) end
local function trigger_cooldown()     return numeric_setting("trigger_cooldown", DEFAULT_TRIGGER_COOLDOWN, 0) end
local function response_mode()        return mod:get("response_mode") or "block" end
local function disable_while_sprinting()   return boolean_setting("disable_while_sprinting", true) end

-- Weapon checks

local function is_combat_sword(weapon_name)
	if not weapon_name then return false end
	for _, pat in ipairs(COMBAT_SWORD_PATTERNS) do
		if string.find(weapon_name, pat) then return true end
	end
	return false
end

-- Single traversal: returns is_melee, is_combat_sword, wielded_slot
local function weapon_state(player_unit)
	local ext, inv, ww = get_weapon_info(player_unit)
	if not ext then return false, false, nil end

	local slot = inv and inv.wielded_slot
	if slot == "slot_primary" then
		local name = ww and ww.weapon_template and ww.weapon_template.name
		return true, is_combat_sword(name), slot
	end

	local keywords = ww and ww.weapon_template and ww.weapon_template.keywords
	local is_melee = keywords and table.array_contains(keywords, "melee") or false
	local name     = ww and ww.weapon_template and ww.weapon_template.name
	return is_melee, is_melee and is_combat_sword(name) or false, slot
end

-- Trigger logic

local function can_trigger_response() return main_time() >= next_trigger_t end
local function begin_trigger_cooldown() next_trigger_t = main_time() + trigger_cooldown() end

local function ui_using_input()
	return Managers and Managers.ui and Managers.ui:using_input() or false
end

local function sprint_requested()
	if not disable_while_sprinting() then return false end

	return cached_sprint_input.sprint
		or cached_sprint_input.sprinting
		or cached_sprint_input.hold_to_sprint
end

local function is_sprinting()
	if not disable_while_sprinting() then return false end

	local ok, result = pcall(function()
		local player_unit = local_player_unit()
		local unit_data_extension = player_unit and ScriptUnit.has_extension(player_unit, "unit_data_system")
		local sprint_component = unit_data_extension and unit_data_extension:read_component("sprint_character_state")
		return sprint_component and sprint_component.is_sprinting
	end)

	return sprint_requested() or sprint_utility_active or (ok and result) or false
end

local function decode_minigame_active()
	local ui = Managers and Managers.ui
	if not ui or not ui.view_active then return false end

	for _, view_name in ipairs(MINIGAME_VIEW_NAMES) do
		local ok, active = pcall(ui.view_active, ui, view_name)
		if ok and active then
			return true
		end
	end

	return false
end

local function long_interaction_active()
	local player_unit = local_player_unit()
	if not player_unit then
		return decode_minigame_active()
	end

	local unit_data_extension = ScriptUnit.has_extension(player_unit, "unit_data_system")
	if not unit_data_extension then
		return decode_minigame_active()
	end

	local interaction_component = unit_data_extension:read_component("interaction")
	if not interaction_component then
		return decode_minigame_active()
	end

	local InteractionSettings = require("scripts/settings/interaction/interaction_settings")
	local interaction_states = InteractionSettings.states
	local state = interaction_component.state

	if state == interaction_states.is_interacting then
		local interaction_type = interaction_component.type
		if not interaction_type then
			return true
		end

		local interaction_templates = require("scripts/settings/interaction/interaction_templates")
		local template = interaction_templates[interaction_type]

		if not template then
			return true
		end

		return template.duration == nil or template.duration > 0
	end

	return decode_minigame_active()
end

local function response_suppressed()
	return is_sprinting() or long_interaction_active()
end

local function mark_block_window(use_weapon_special)
	local start_t = main_time() + block_delay()
	block_start_t      = math.max(block_start_t, start_t)
	block_until_t      = math.max(block_until_t, start_t + block_duration())
	parry_press_queued = use_weapon_special
end

local function queue_dodge()
	local start_t = main_time() + dodge_delay()
	dodge_start_t = math.max(dodge_start_t, start_t)
	dodge_until_t = math.max(dodge_until_t, start_t + dodge_queue_duration())
end

local function can_use_melee_response(player_unit)
	local is_melee, use_special, slot = weapon_state(player_unit)
	local usable = is_melee and slot ~= "slot_secondary" and slot ~= "slot_grenade_ability"
	return usable, use_special
end

-- Input hook

local function input_hook(func, self, action_name)
	local value = func(self, action_name)

	if self.type ~= "Ingame" then return value end

	if SPRINT_INPUT_ACTIONS[action_name] then
		cached_sprint_input[action_name] = value and true or false
	end

	-- Fast-exit: only intercept the five response actions
	if action_name ~= "weapon_extra_pressed"
	and action_name ~= "weapon_extra_hold"
	and action_name ~= "action_two_hold"
	and action_name ~= "dodge" then
		return value
	end

	-- Shared guard: one player_unit + ui check for all branches
	if not mod:is_enabled() or not setting_enabled or ui_using_input() or response_suppressed() then return value end

	local t = main_time()

	if action_name == "dodge" then
		if dodge_start_t <= t and dodge_until_t > t then
			dodge_until_t = 0
			dodge_start_t = 0
			local mode = response_mode()
			if mode == "dodge" or mode == "both" then
				local pu = local_player_unit()
				if pu and Unit.alive(pu) then return true end
			end
		end
		return value
	end

	-- Block / weapon-special actions
	if block_start_t > t or block_until_t <= t then return value end

	local pu = local_player_unit()
	if not pu or not Unit.alive(pu) then return value end

	local mode = response_mode()
	if mode ~= "block" and mode ~= "both" then return value end

	local can_use_melee, use_special = can_use_melee_response(pu)
	if not can_use_melee then return value end

	if action_name == "weapon_extra_pressed" and use_special and parry_press_queued then
		parry_press_queued = false
		return true
	end

	if action_name == "weapon_extra_hold" and use_special then
		return true
	end

	if action_name == "action_two_hold" and not use_special then
		return true
	end

	return value
end

-- Mod lifecycle

mod.on_all_mods_loaded = function()
	mod:hook_require("scripts/extension_systems/character_state_machine/character_states/utilities/sprint", function(Sprint)
		mod:hook_safe(Sprint, "sprint_input", function(_input_source, sprinting, ...)
			sprint_utility_active = sprinting and true or false
		end)
	end)

	mod:hook_safe(WwiseWorld, "trigger_resource_event", function(_wwise_world, wwise_event_name, unit_or_pos)
		-- Backstab response
		if BACKSTAB_MELEE_EVENTS[wwise_event_name] and mod:is_enabled() and setting_enabled and not response_suppressed() then
			if can_trigger_response() then
				local pu = local_player_unit()
				if pu then
					local event_targets_other_unit = false
					if type(unit_or_pos) == "userdata" then
						local ok, is_valid = pcall(Unit.is_valid, unit_or_pos)
						event_targets_other_unit = ok and is_valid and unit_or_pos ~= pu
					end

					if not event_targets_other_unit then
						local mode = response_mode()
						local triggered = false

						if mode == "dodge" or mode == "both" then
							queue_dodge()
							triggered = true
						end

						if mode == "block" or mode == "both" then
							local can_use_melee, use_special = can_use_melee_response(pu)
							if can_use_melee then
								mark_block_window(use_special)
								triggered = true
							end
						end

						if triggered then begin_trigger_cooldown() end
					end
				end
			end
		end
	end)

	mod:hook(CLASS.InputService, "_get", input_hook)
	mod:hook(CLASS.InputService, "_get_simulate", input_hook)
end

mod.update = function()
	if mod:is_enabled() and setting_enabled and response_suppressed() then
		reset_response_state()
		return
	end

	-- Only do work when timers are actually active
	local t = main_time()
	if block_until_t > 0 and block_until_t <= t then
		block_start_t      = 0
		block_until_t      = 0
		parry_press_queued = false
	end
	if dodge_until_t > 0 and dodge_until_t <= t then
		dodge_start_t = 0
		dodge_until_t = 0
	end
end

function mod.toggle_mod_enabled(pressed)
	if pressed == false then
		return
	end

	setting_enabled = not refresh_enabled_setting()
	mod:set("enable_mod", setting_enabled)

	if not setting_enabled then
		reset_response_state()
	end

	mod:notify(string.format("RearGuard: %s", setting_enabled and "Enabled" or "Disabled"))
end

mod.cycle_response_mode = function()
	local mode     = response_mode()
	local new_mode = mode == "block" and "dodge" or mode == "dodge" and "both" or "block"
	mod:set("response_mode", new_mode)

	local loc_id = new_mode == "dodge" and "response_mode_dodge"
		or new_mode == "both" and "response_mode_both"
		or "response_mode_block"
	mod:echo_localized("response_mode_switched", mod:localize(loc_id))
end

mod.on_setting_changed = function(setting_id)
	if setting_id == "enable_mod" then
		refresh_enabled_setting()

		if not setting_enabled then
			reset_response_state()
		end
	end
end

mod.on_disabled = function()
	cached_sprint_input.sprint = false
	cached_sprint_input.sprinting = false
	cached_sprint_input.hold_to_sprint = false
	sprint_utility_active = false
	refresh_enabled_setting()
	reset_response_state()
end

refresh_enabled_setting()

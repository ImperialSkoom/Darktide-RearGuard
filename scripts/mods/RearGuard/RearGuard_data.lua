local mod = get_mod("RearGuard")
return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	allow_rehooking = true,
	options = {
		widgets = {
			{
				setting_id = "global_settings",
				type = "group",
				sub_widgets = {
					{
						setting_id = "enable_mod",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "toggle_mod_keybind",
						tooltip = "toggle_mod_keybind_description",
						type = "keybind",
						default_value = {},
						keybind_trigger = "pressed",
						keybind_type = "function_call",
						function_name = "toggle_mod_enabled",
					},
					{
						setting_id = "disable_while_sprinting",
						type = "checkbox",
						default_value = true,
					},
				},
			},
			{
				setting_id = "response_settings",
				type = "group",
				sub_widgets = {
					{
						setting_id = "response_mode",
						type = "dropdown",
						default_value = "block",
						options = {
							{ text = "response_mode_block", value = "block" },
							{ text = "response_mode_dodge", value = "dodge" },
							{ text = "response_mode_both", value = "both" },
						},
					},
					{
						setting_id = "cycle_response_mode_keybind",
						tooltip = "cycle_response_mode_keybind_description",
						type = "keybind",
						default_value = {},
						keybind_trigger = "pressed",
						keybind_type = "function_call",
						function_name = "cycle_response_mode",
					},
				},
			},
			{
				setting_id = "timing_settings",
				type = "group",
				sub_widgets = {
					{
						setting_id = "block_delay",
						type = "numeric",
						default_value = 0.10,
						range = { 0.0, 0.5 },
						decimals_number = 2,
					},
					{
						setting_id = "block_duration",
						type = "numeric",
						default_value = 0.60,
						range = { 0.1, 1.5 },
						decimals_number = 2,
					},
					{
						setting_id = "dodge_delay",
						type = "numeric",
						default_value = 0.10,
						range = { 0.0, 0.3 },
						decimals_number = 2,
					},
					{
						setting_id = "dodge_queue_duration",
						type = "numeric",
						default_value = 0.20,
						range = { 0.05, 0.5 },
						decimals_number = 2,
					},
					{
						setting_id = "trigger_cooldown",
						type = "numeric",
						default_value = 0.10,
						range = { 0.0, 1.0 },
						decimals_number = 2,
					},
				},
			},
		},
	},
}

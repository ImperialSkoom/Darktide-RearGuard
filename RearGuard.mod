return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`Rear Guard` encountered an error loading the Darktide Mod Framework.")

		new_mod("RearGuard", {
			mod_script       = "RearGuard/scripts/mods/RearGuard/RearGuard",
			mod_data         = "RearGuard/scripts/mods/RearGuard/RearGuard_data",
			mod_localization = "RearGuard/scripts/mods/RearGuard/RearGuard_localization",
		})
	end,
	packages = {},
}

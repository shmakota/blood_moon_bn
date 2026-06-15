gdebug.log_info("Blood Moon: preload")

---@class ModBloodMoon
---@field announce_transition fun()
---@field configure_interval fun()
---@field on_game_load fun()
---@field on_game_started fun()
---@field on_horde_tick fun(): boolean?
---@field on_monster_loaded fun(params: { monster: Monster })
---@field on_monster_spawn fun(params: { monster: Monster })
---@field on_monster_try_move fun(params: { monster: Monster, from: TripointBubMs, to: TripointBubMs, force: boolean })
---@field on_tracking_tick fun(): boolean?
---@type ModBloodMoon
local mod = game.mod_runtime[game.current_mod]

game.add_hook("on_game_started", function(...) return mod.on_game_started(...) end)
game.add_hook("on_game_load", function(...) return mod.on_game_load(...) end)
game.add_hook("on_monster_loaded", function(...) return mod.on_monster_loaded(...) end)
game.add_hook("on_monster_spawn", function(...) return mod.on_monster_spawn(...) end)
game.add_hook("on_monster_try_move", function(...) return mod.on_monster_try_move(...) end)
gapi.add_on_every_x_hook(TimeDuration.from_minutes(1), function() return mod.announce_transition() end)
gapi.add_on_every_x_hook(TimeDuration.from_minutes(1), function() return mod.on_tracking_tick() end)
gapi.add_on_every_x_hook(TimeDuration.from_minutes(5), function() return mod.on_horde_tick() end)

gapi.register_action_menu_entry({
  id = "blood_moon_configure_interval",
  name = "Configure Blood Moon",
  category = "misc",
  fn = function() mod.configure_interval() end,
})

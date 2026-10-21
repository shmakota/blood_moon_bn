gdebug.log_info("Blood Moon: preload")

---@type ModBloodMoon
local mod = game.mod_runtime[game.current_mod]

game.add_hook("on_game_started", function() mod.on_game_started() end)
game.add_hook("on_game_load", function() mod.on_game_load() end)
---@param params { monster: Monster }
local on_monster_loaded = function(params) return mod.on_monster_loaded(params) end
game.add_hook("on_monster_loaded", on_monster_loaded)
---@param params { monster: Monster }
local on_monster_spawn = function(params) return mod.on_monster_spawn(params) end
game.add_hook("on_monster_spawn", on_monster_spawn)
---@param params { monster: Monster, from: TripointBubMs, to: TripointBubMs, force: boolean }
local on_monster_try_move = function(params) return mod.on_monster_try_move(params) end
game.add_hook("on_monster_try_move", on_monster_try_move)
gapi.add_on_every_x_hook(TimeDuration.from_minutes(1), function() return mod.announce_transition() end)
gapi.add_on_every_x_hook(TimeDuration.from_minutes(1), function() return mod.on_tracking_tick() end)
gapi.add_on_every_x_hook(TimeDuration.from_minutes(5), function() return mod.on_horde_tick() end)

gapi.register_action_menu_entry({
  id = "blood_moon_configure_interval",
  name = "Configure Blood Moon",
  category = "misc",
  fn = function() mod.configure_interval() end,
})

---@param params ItemUseParams
local use_blood_moon_clock = function(params) return mod.use_blood_moon_clock(params) end
game.iuse_functions["BLOOD_MOON_CLOCK"] = use_blood_moon_clock

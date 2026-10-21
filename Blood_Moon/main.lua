gdebug.log_info("Blood Moon: main")

---@type ModBloodMoon
local mod = game.mod_runtime[game.current_mod]
---@type BloodMoonStorage
local storage = game.mod_storage[game.current_mod]

require("./blood_moon_config").register(mod, storage)
require("./blood_moon_schedule").register(mod, storage)
require("./blood_moon_hordes").register(mod, storage)
require("./blood_moon_menu").register(mod, storage)
require("./blood_moon_clock").register(mod, storage)

---@type ModBloodMoon
local mod = game.mod_runtime[game.current_mod]
local constants = require("./blood_moon_constants")
local gettext = locale.gettext

---@type BMPreset
local _PRESET_RELAXED = {
  name = "Relaxed",
  desc = "14 days between hordes and slower increasing difficulty.",
  horde_signal_power = 5,
  horde_days_per_signal_growth = 8,
  horde_max_signal_growth = 2,
  spawn_signal_power = constants.DEFAULT_SPAWN_SIGNAL_POWER,
  spawn_days_per_signal_growth = 8,
  spawn_max_signal_growth = constants.DEFAULT_SPAWN_MAX_SIGNAL_GROWTH,
  population_per_signal = constants.DEFAULT_POPULATION_PER_SIGNAL,
  group_id = constants.HORDE_GROUP_ID,
  interval = 14,
  multiplier = 5,
  spawn_pulse_interval = 3,
  spawned_hordes_per_tick = constants.DEFAULT_SPAWNED_HORDES_PER_TICK,
}

---@type BMPreset
local _PRESET_STANDARD = {
  name = "Standard",
  desc = "7 days between hordes and default difficulty values.",
  horde_signal_power = constants.DEFAULT_HORDE_SIGNAL_POWER,
  horde_days_per_signal_growth = constants.DEFAULT_HORDE_DAYS_PER_SIGNAL_GROWTH,
  horde_max_signal_growth = constants.DEFAULT_HORDE_MAX_SIGNAL_GROWTH,
  spawn_signal_power = constants.DEFAULT_SPAWN_SIGNAL_POWER,
  spawn_days_per_signal_growth = constants.DEFAULT_SPAWN_DAYS_PER_SIGNAL_GROWTH,
  spawn_max_signal_growth = constants.DEFAULT_SPAWN_MAX_SIGNAL_GROWTH,
  population_per_signal = constants.DEFAULT_POPULATION_PER_SIGNAL,
  group_id = constants.HORDE_GROUP_ID,
  interval = constants.DEFAULT_INTERVAL_DAYS,
  multiplier = constants.DEFAULT_MULTIPLIER,
  spawn_pulse_interval = constants.DEFAULT_SPAWN_PULSE_INTERVAL,
  spawned_hordes_per_tick = constants.DEFAULT_SPAWNED_HORDES_PER_TICK,
}

---@type BMPreset
local _PRESET_CHALLENGING = {
  name = "Challenging",
  desc = "2 days between hordes with faster increasing difficulty.",
  horde_signal_power = constants.DEFAULT_HORDE_SIGNAL_POWER,
  horde_days_per_signal_growth = 2,
  horde_max_signal_growth = constants.DEFAULT_HORDE_MAX_SIGNAL_GROWTH,
  spawn_signal_power = constants.DEFAULT_SPAWN_SIGNAL_POWER,
  spawn_days_per_signal_growth = 2,
  spawn_max_signal_growth = constants.DEFAULT_SPAWN_MAX_SIGNAL_GROWTH,
  population_per_signal = constants.DEFAULT_POPULATION_PER_SIGNAL,
  group_id = constants.HORDE_GROUP_ID,
  interval = 2,
  multiplier = constants.DEFAULT_MULTIPLIER,
  spawn_pulse_interval = constants.DEFAULT_SPAWN_PULSE_INTERVAL,
  spawned_hordes_per_tick = constants.DEFAULT_SPAWNED_HORDES_PER_TICK,
}

---@type BMPreset[]
local presets = {
  _PRESET_RELAXED,
  _PRESET_STANDARD,
  _PRESET_CHALLENGING,
}

---@type BMPreset
local DEFAULT_PRESET = _PRESET_STANDARD

---@param preset BMPreset
local function apply_preset(preset)
  mod.set_interval(preset.interval)
  mod.set_multiplier(preset.multiplier)
  mod.set_group_id(preset.group_id)
  mod.set_population_per_signal(preset.population_per_signal)

  mod.set_horde_signal_power(preset.horde_signal_power)
  mod.set_horde_days_per_signal_growth(preset.horde_days_per_signal_growth)
  mod.set_horde_max_signal_growth(preset.horde_max_signal_growth)

  mod.set_spawn_signal_power(preset.spawn_signal_power)
  mod.set_spawn_days_per_signal_growth(preset.spawn_days_per_signal_growth)
  mod.set_spawn_pulse_interval(preset.spawn_pulse_interval)
  mod.set_spawn_max_signal_growth(preset.spawn_max_signal_growth)
  mod.set_spawned_hordes_per_tick(preset.spawned_hordes_per_tick)
end

local function show_select_preset()
  local menu = UiList.new()
  menu:desc_enabled(true)
  menu:title(gettext("Select Blood Moon Preset"))
  menu:text(gettext("Default is Standard, can be customized manually later via the in-game menu."))
  for idx, preset in ipairs(presets) do
    menu:add_w_desc(idx, gettext(preset.name), gettext(preset.desc))
  end
  local choice = menu:query()
  if choice < 0 then
    apply_preset(DEFAULT_PRESET)
  else
    apply_preset(presets[choice])
  end
end

return {
  show_select_preset = show_select_preset,
}

local constants = require("./blood_moon_constants")
local config = {}

---@param mod ModBloodMoon
---@param storage BloodMoonStorage
config.register = function(mod, storage)
  ---@param value integer?
  ---@return integer
  mod.sanitize_interval = function(value)
    if type(value) ~= "number" then return constants.DEFAULT_INTERVAL_DAYS end

    local floored = math.floor(value)
    if floored < 1 then return constants.DEFAULT_INTERVAL_DAYS end

    return floored
  end

  ---@param value integer?
  ---@return integer
  mod.sanitize_multiplier = function(value)
    if type(value) ~= "number" then return constants.DEFAULT_MULTIPLIER end

    local floored = math.floor(value)
    if floored < 1 then return constants.DEFAULT_MULTIPLIER end

    return floored
  end

  ---@param value integer?
  ---@return integer
  mod.sanitize_signal_power = function(value)
    if type(value) ~= "number" then return constants.DEFAULT_HORDE_SIGNAL_POWER end

    local floored = math.floor(value)
    if floored < 0 then return constants.DEFAULT_HORDE_SIGNAL_POWER end

    return floored
  end

  ---@param value integer?
  ---@return integer
  mod.sanitize_days_per_signal_growth = function(value)
    if type(value) ~= "number" then return constants.DEFAULT_HORDE_DAYS_PER_SIGNAL_GROWTH end

    local floored = math.floor(value)
    if floored < 1 then return constants.DEFAULT_HORDE_DAYS_PER_SIGNAL_GROWTH end

    return floored
  end

  ---@param value integer?
  ---@return integer
  mod.sanitize_max_signal_growth = function(value)
    if type(value) ~= "number" then return constants.DEFAULT_HORDE_MAX_SIGNAL_GROWTH end

    local floored = math.floor(value)
    if floored < 0 then return constants.DEFAULT_HORDE_MAX_SIGNAL_GROWTH end

    return floored
  end

  ---@param value integer?
  ---@return integer
  mod.sanitize_spawned_hordes_per_tick = function(value)
    if type(value) ~= "number" then return constants.DEFAULT_SPAWNED_HORDES_PER_TICK end

    local floored = math.floor(value)
    if floored < 0 then return constants.DEFAULT_SPAWNED_HORDES_PER_TICK end

    return floored
  end

  ---@param value integer?
  ---@return integer
  mod.sanitize_population_per_signal = function(value)
    if type(value) ~= "number" then return constants.DEFAULT_POPULATION_PER_SIGNAL end

    local floored = math.floor(value)
    if floored < 1 then return constants.DEFAULT_POPULATION_PER_SIGNAL end

    return floored
  end

  ---@param value integer?
  ---@return integer
  mod.sanitize_spawn_pulse_interval = function(value)
    if type(value) ~= "number" then return constants.DEFAULT_SPAWN_PULSE_INTERVAL end

    local floored = math.floor(value)
    if floored < 1 then return constants.DEFAULT_SPAWN_PULSE_INTERVAL end

    return floored
  end

  ---@param value string?
  ---@return string
  mod.sanitize_group_id = function(value)
    if type(value) ~= "string" then return constants.HORDE_GROUP_ID end

    local trimmed = value:match("^%s*(.-)%s*$")
    if trimmed == "" then return constants.HORDE_GROUP_ID end

    return trimmed
  end

  ---@param value integer
  mod.set_interval = function(value) storage.interval_days = mod.sanitize_interval(value) end

  ---@param value integer
  mod.set_multiplier = function(value) storage.multiplier = mod.sanitize_multiplier(value) end

  ---@param value integer
  mod.set_horde_signal_power = function(value) storage.horde_signal_power = mod.sanitize_signal_power(value) end

  ---@param value integer
  mod.set_horde_days_per_signal_growth =
    function(value) storage.horde_days_per_signal_growth = mod.sanitize_days_per_signal_growth(value) end

  ---@param value integer
  mod.set_horde_max_signal_growth =
    function(value) storage.horde_max_signal_growth = mod.sanitize_max_signal_growth(value) end

  ---@param value integer
  mod.set_spawn_signal_power = function(value) storage.spawn_signal_power = mod.sanitize_signal_power(value) end

  ---@param value integer
  mod.set_spawn_days_per_signal_growth =
    function(value) storage.spawn_days_per_signal_growth = mod.sanitize_days_per_signal_growth(value) end

  ---@param value integer
  mod.set_spawn_max_signal_growth =
    function(value) storage.spawn_max_signal_growth = mod.sanitize_max_signal_growth(value) end

  ---@param value integer
  mod.set_spawned_hordes_per_tick =
    function(value) storage.spawned_hordes_per_tick = mod.sanitize_spawned_hordes_per_tick(value) end

  ---@param value integer
  mod.set_population_per_signal =
    function(value) storage.population_per_signal = mod.sanitize_population_per_signal(value) end

  ---@param value integer
  mod.set_spawn_pulse_interval =
    function(value) storage.spawn_pulse_interval = mod.sanitize_spawn_pulse_interval(value) end

  ---@param value string
  mod.set_group_id = function(value) storage.group_id = mod.sanitize_group_id(value) end

  storage.horde_signal_power = storage.horde_signal_power or storage.signal_power
  storage.horde_days_per_signal_growth = storage.horde_days_per_signal_growth or storage.days_per_signal_growth
  storage.horde_max_signal_growth = storage.horde_max_signal_growth or storage.max_signal_growth
  storage.spawn_signal_power = storage.spawn_signal_power or storage.signal_power
  storage.spawn_days_per_signal_growth = storage.spawn_days_per_signal_growth or storage.days_per_signal_growth
  storage.spawn_max_signal_growth = storage.spawn_max_signal_growth or storage.max_signal_growth

  mod.set_interval(storage.interval_days)
  mod.set_multiplier(storage.multiplier)
  mod.set_horde_signal_power(storage.horde_signal_power)
  mod.set_horde_days_per_signal_growth(storage.horde_days_per_signal_growth)
  mod.set_horde_max_signal_growth(storage.horde_max_signal_growth)
  mod.set_spawn_signal_power(storage.spawn_signal_power)
  mod.set_spawn_days_per_signal_growth(storage.spawn_days_per_signal_growth)
  mod.set_spawn_max_signal_growth(storage.spawn_max_signal_growth)
  mod.set_spawned_hordes_per_tick(storage.spawned_hordes_per_tick)
  mod.set_population_per_signal(storage.population_per_signal)
  mod.set_spawn_pulse_interval(storage.spawn_pulse_interval)
  mod.set_group_id(storage.group_id)
  storage.active = nil
end

return config

gdebug.log_info("Blood Moon: main")

local ui = require("lib.ui")

---@class BloodMoonStorage
---@field interval_days integer?
---@field multiplier integer?
---@field horde_signal_power integer?
---@field horde_days_per_signal_growth integer?
---@field horde_max_signal_growth integer?
---@field spawn_signal_power integer?
---@field spawn_days_per_signal_growth integer?
---@field spawn_max_signal_growth integer?
---@field spawned_hordes_per_tick integer?
---@field population_per_signal integer?
---@field spawn_pulse_interval integer?
---@field group_id string?
local storage = game.mod_storage[game.current_mod]

---@class ModBloodMoon
---@field active boolean?
---@field announce_transition fun()
---@field blood_moon_day_number fun(turn: TimePoint): integer
---@field configure_interval fun()
---@field current_horde_signal_power fun(turn: TimePoint): integer
---@field current_spawn_signal_power fun(turn: TimePoint): integer
---@field current_scaled_signal_power fun(turn: TimePoint, base_signal_power: integer?, days_per_signal_growth: integer?, max_signal_growth: integer?): integer
---@field is_blood_moon_night fun(turn: TimePoint): boolean
---@field surface_omt fun(pos: TripointAbsOmt): TripointAbsOmt
---@field surface_sm fun(pos: TripointAbsSm): TripointAbsSm
---@field min_spawn_distance_omt fun(): integer
---@field max_spawn_distance_omt fun(): integer
---@field next_blood_moon_start_turn fun(): TimePoint
---@field next_blood_moon_horde_turn fun(): TimePoint
---@field next_horde_preview_text fun(): string
---@field on_monster_loaded fun(params: { monster: Monster })
---@field on_monster_spawn fun(params: { monster: Monster })
---@field on_monster_try_move fun(params: { monster: Monster, from: TripointBubMs, to: TripointBubMs, force: boolean })
---@field on_game_load fun()
---@field on_game_started fun()
---@field on_horde_tick fun(): boolean?
---@field on_tracking_tick fun(): boolean?
---@field random_message fun(messages: string[]): string
---@field prompt_setting fun(title: string, description: string): integer?
---@field prompt_string_setting fun(title: string, description: string): string?
---@field refresh_blood_moon_hordes fun(avatar_sm: TripointAbsSm)
---@field steer_zombie_toward_player fun(monster: Monster, avatar_pos: TripointBubMs)
---@field is_blood_moon_zombie fun(monster: Monster): boolean
---@field sanitize_days_per_signal_growth fun(value: integer?): integer
---@field sanitize_group_id fun(value: string?): string
---@field sanitize_interval fun(value: integer?): integer
---@field sanitize_max_signal_growth fun(value: integer?): integer
---@field sanitize_multiplier fun(value: integer?): integer
---@field sanitize_population_per_signal fun(value: integer?): integer
---@field sanitize_signal_power fun(value: integer?): integer
---@field sanitize_spawn_pulse_interval fun(value: integer?): integer
---@field sanitize_spawned_hordes_per_tick fun(value: integer?): integer
---@field set_horde_signal_power fun(value: integer)
---@field set_horde_days_per_signal_growth fun(value: integer)
---@field set_horde_max_signal_growth fun(value: integer)
---@field set_spawn_signal_power fun(value: integer)
---@field set_spawn_days_per_signal_growth fun(value: integer)
---@field set_spawn_max_signal_growth fun(value: integer)
---@field set_population_per_signal fun(value: integer)
---@field set_group_id fun(value: string)
---@field set_interval fun(value: integer)
---@field set_multiplier fun(value: integer)
---@field set_spawn_pulse_interval fun(value: integer)
---@field set_spawned_hordes_per_tick fun(value: integer)
---@field spawn_horde_population fun(turn: TimePoint): integer
---@field spawn_hordes_around_player fun(turn: TimePoint)
---@field random_horde_spawn_offset fun(): TripointRelOmt
---@field count_turn_multiples_between fun(start_turn: TimePoint, end_turn: TimePoint, interval_turns: integer): integer
---@field blood_moon_evening_start_turn fun(turn: TimePoint): TimePoint
---@field should_spawn_hordes fun(turn: TimePoint): boolean
---@field night_spawn_estimate_text fun(start_turn: TimePoint): string
---@field sync_active_state fun()
---@type ModBloodMoon
local mod = game.mod_runtime[game.current_mod]

local gettext = locale.gettext
local DEFAULT_INTERVAL_DAYS = 7
local DEFAULT_MULTIPLIER = 10
local DEFAULT_HORDE_SIGNAL_POWER = 10
local DEFAULT_HORDE_DAYS_PER_SIGNAL_GROWTH = 4
local DEFAULT_HORDE_MAX_SIGNAL_GROWTH = 3
local DEFAULT_SPAWN_SIGNAL_POWER = 1
local DEFAULT_SPAWN_DAYS_PER_SIGNAL_GROWTH = 4
local DEFAULT_SPAWN_MAX_SIGNAL_GROWTH = 3
local DEFAULT_SPAWNED_HORDES_PER_TICK = 1
local DEFAULT_POPULATION_PER_SIGNAL = 1
local DEFAULT_SPAWN_PULSE_INTERVAL = 3
local HORDE_TICK_INTERVAL_TURNS = 300
local HORDE_GROUP_ID = "GROUP_ZOMBIE"
local BLOOD_MOON_HORDE_BEHAVIOUR = "blood_moon_hunt"
local BLOOD_MOON_START_HOUR = 21
local HORDE_TARGET_REFRESH_RADIUS_OMT = 12
local HORDE_FALLBACK_MIN_SPAWN_DISTANCE_OMT = 4
local HORDE_SPAWN_DISTANCE_BUFFER_OMT = 1
local HORDE_SPAWN_RING_WIDTH_OMT = 2
local BLOOD_MOON_MONSTER_ANGER = 100
local BLOOD_MOON_MONSTER_MORALE = 100
local BLOOD_MOON_MONSTER_WANDER_STRENGTH = 200
local ZOMBIE_SPECIES_ID = SpeciesTypeId.new("ZOMBIE")

local BLOOD_MOON_START_MESSAGES = {
  gettext("A crimson moon claws its way above the horizon.  Every horde in the dark has your scent."),
  gettext("The sky turns the color of fresh blood.  Far-off moans answer as the hordes begin to hunt."),
  gettext("Moonlight curdles into red.  The dead stir as if they have caught your trail all at once."),
}

local BLOOD_MOON_END_MESSAGES = {
  gettext("Dawn bleeds across the sky.  The blood moon loosens its grip, and the hordes begin to scatter."),
  gettext("The red glow fades from the heavens.  The dead lose their furious purpose and wander once more."),
  gettext("Morning light breaks the blood moon's spell.  The howling pursuit slackens in the distance."),
}

game.horde_behaviours[BLOOD_MOON_HORDE_BEHAVIOUR] = function(params)
  params.results.target = mod.surface_sm(gapi.get_avatar():global_sm_location())
  params.results.interest = 100
end

---@param messages string[]
---@return string
mod.random_message = function(messages)
  return messages[gapi.rng(1, #messages)]
end

---@param pos TripointAbsOmt
---@return TripointAbsOmt
mod.surface_omt = function(pos)
  return TripointAbsOmt.new(pos.x, pos.y, 0)
end

---@param pos TripointAbsSm
---@return TripointAbsSm
mod.surface_sm = function(pos)
  return TripointAbsSm.new(pos.x, pos.y, 0)
end

---@return integer
mod.min_spawn_distance_omt = function()
  local map = gapi.get_map()
  if map == nil or type(map.get_map_size_in_submaps) ~= "function" then
    return HORDE_FALLBACK_MIN_SPAWN_DISTANCE_OMT
  end

  local map_size_submaps = map:get_map_size_in_submaps()
  local half_size_submaps = math.floor(map_size_submaps / 2)
  local loaded_radius_omt = math.ceil((half_size_submaps + 1) / 2)
  return loaded_radius_omt + HORDE_SPAWN_DISTANCE_BUFFER_OMT
end

---@return integer
mod.max_spawn_distance_omt = function()
  return mod.min_spawn_distance_omt() + HORDE_SPAWN_RING_WIDTH_OMT
end

---@param value integer?
---@return integer
mod.sanitize_interval = function(value)
  if type(value) ~= "number" then
    return DEFAULT_INTERVAL_DAYS
  end

  local floored = math.floor(value)
  if floored < 1 then
    return DEFAULT_INTERVAL_DAYS
  end

  return floored
end

---@param value integer?
---@return integer
mod.sanitize_multiplier = function(value)
  if type(value) ~= "number" then
    return DEFAULT_MULTIPLIER
  end

  local floored = math.floor(value)
  if floored < 1 then
    return DEFAULT_MULTIPLIER
  end

  return floored
end

---@param value integer?
---@return integer
mod.sanitize_signal_power = function(value)
  if type(value) ~= "number" then
    return DEFAULT_HORDE_SIGNAL_POWER
  end

  local floored = math.floor(value)
  if floored < 0 then
    return DEFAULT_HORDE_SIGNAL_POWER
  end

  return floored
end

---@param value integer?
---@return integer
mod.sanitize_days_per_signal_growth = function(value)
  if type(value) ~= "number" then
    return DEFAULT_HORDE_DAYS_PER_SIGNAL_GROWTH
  end

  local floored = math.floor(value)
  if floored < 1 then
    return DEFAULT_HORDE_DAYS_PER_SIGNAL_GROWTH
  end

  return floored
end

---@param value integer?
---@return integer
mod.sanitize_max_signal_growth = function(value)
  if type(value) ~= "number" then
    return DEFAULT_HORDE_MAX_SIGNAL_GROWTH
  end

  local floored = math.floor(value)
  if floored < 0 then
    return DEFAULT_HORDE_MAX_SIGNAL_GROWTH
  end

  return floored
end

---@param value integer?
---@return integer
mod.sanitize_spawned_hordes_per_tick = function(value)
  if type(value) ~= "number" then
    return DEFAULT_SPAWNED_HORDES_PER_TICK
  end

  local floored = math.floor(value)
  if floored < 0 then
    return DEFAULT_SPAWNED_HORDES_PER_TICK
  end

  return floored
end

---@param value integer?
---@return integer
mod.sanitize_population_per_signal = function(value)
  if type(value) ~= "number" then
    return DEFAULT_POPULATION_PER_SIGNAL
  end

  local floored = math.floor(value)
  if floored < 1 then
    return DEFAULT_POPULATION_PER_SIGNAL
  end

  return floored
end

---@param value integer?
---@return integer
mod.sanitize_spawn_pulse_interval = function(value)
  if type(value) ~= "number" then
    return DEFAULT_SPAWN_PULSE_INTERVAL
  end

  local floored = math.floor(value)
  if floored < 1 then
    return DEFAULT_SPAWN_PULSE_INTERVAL
  end

  return floored
end

---@param value string?
---@return string
mod.sanitize_group_id = function(value)
  if type(value) ~= "string" then
    return HORDE_GROUP_ID
  end

  local trimmed = value:match("^%s*(.-)%s*$")
  if trimmed == "" then
    return HORDE_GROUP_ID
  end

  return trimmed
end

---@param value integer
mod.set_interval = function(value)
  storage.interval_days = mod.sanitize_interval(value)
end

---@param value integer
mod.set_multiplier = function(value)
  storage.multiplier = mod.sanitize_multiplier(value)
end

---@param value integer
mod.set_horde_signal_power = function(value)
  storage.horde_signal_power = mod.sanitize_signal_power(value)
end

---@param value integer
mod.set_horde_days_per_signal_growth = function(value)
  storage.horde_days_per_signal_growth = mod.sanitize_days_per_signal_growth(value)
end

---@param value integer
mod.set_horde_max_signal_growth = function(value)
  storage.horde_max_signal_growth = mod.sanitize_max_signal_growth(value)
end

---@param value integer
mod.set_spawn_signal_power = function(value)
  storage.spawn_signal_power = mod.sanitize_signal_power(value)
end

---@param value integer
mod.set_spawn_days_per_signal_growth = function(value)
  storage.spawn_days_per_signal_growth = mod.sanitize_days_per_signal_growth(value)
end

---@param value integer
mod.set_spawn_max_signal_growth = function(value)
  storage.spawn_max_signal_growth = mod.sanitize_max_signal_growth(value)
end

---@param value integer
mod.set_spawned_hordes_per_tick = function(value)
  storage.spawned_hordes_per_tick = mod.sanitize_spawned_hordes_per_tick(value)
end

---@param value integer
mod.set_population_per_signal = function(value)
  storage.population_per_signal = mod.sanitize_population_per_signal(value)
end

---@param value integer
mod.set_spawn_pulse_interval = function(value)
  storage.spawn_pulse_interval = mod.sanitize_spawn_pulse_interval(value)
end

---@param value string
mod.set_group_id = function(value)
  storage.group_id = mod.sanitize_group_id(value)
end

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
mod.active = nil

---@param turn TimePoint
---@return integer
mod.blood_moon_day_number = function(turn)
  return (turn - gapi.turn_zero()):to_days() + 1
end

---@param turn TimePoint
---@return boolean
mod.is_blood_moon_night = function(turn)
  local interval_days = mod.sanitize_interval(storage.interval_days)
  local day_number = mod.blood_moon_day_number(turn)
  local hour_of_day = turn:hour_of_day()

  if hour_of_day >= BLOOD_MOON_START_HOUR then
    return day_number % interval_days == 0
  end

  if day_number <= 1 then
    return false
  end

  return turn:is_night() and (day_number - 1) % interval_days == 0
end

---@param turn TimePoint
---@param base_signal_power integer?
---@param days_per_signal_growth integer?
---@param max_signal_growth integer?
---@return integer
mod.current_scaled_signal_power = function(turn, base_signal_power, days_per_signal_growth, max_signal_growth)
  local elapsed_days = (turn - gapi.turn_zero()):to_days()
  local sanitized_signal_power = mod.sanitize_signal_power(base_signal_power)
  local sanitized_days_per_signal_growth = mod.sanitize_days_per_signal_growth(days_per_signal_growth)
  local sanitized_max_signal_growth = mod.sanitize_max_signal_growth(max_signal_growth)
  local signal_growth = math.min(
    math.floor(elapsed_days / sanitized_days_per_signal_growth),
    sanitized_max_signal_growth
  )
  return sanitized_signal_power + signal_growth
end

---@param turn TimePoint
---@return integer
mod.current_horde_signal_power = function(turn)
  return mod.current_scaled_signal_power(
    turn,
    storage.horde_signal_power,
    storage.horde_days_per_signal_growth,
    storage.horde_max_signal_growth
  )
end

---@param turn TimePoint
---@return integer
mod.current_spawn_signal_power = function(turn)
  return mod.current_scaled_signal_power(
    turn,
    storage.spawn_signal_power,
    storage.spawn_days_per_signal_growth,
    storage.spawn_max_signal_growth
  )
end

---@param turn TimePoint
---@return integer
mod.spawn_horde_population = function(turn)
  local spawn_signal_power = mod.current_spawn_signal_power(turn)
  return spawn_signal_power * mod.sanitize_population_per_signal(storage.population_per_signal)
end

---@param turn TimePoint
---@return integer
mod.current_signal_power = function(turn)
  return mod.current_horde_signal_power(turn)
end

---@return TripointRelOmt
mod.random_horde_spawn_offset = function()
  local min_spawn_distance = mod.min_spawn_distance_omt()
  local max_spawn_distance = mod.max_spawn_distance_omt()
  while true do
    local dx = gapi.rng(-max_spawn_distance, max_spawn_distance)
    local dy = gapi.rng(-max_spawn_distance, max_spawn_distance)
    local distance = math.max(math.abs(dx), math.abs(dy))
    if distance >= min_spawn_distance and distance <= max_spawn_distance then
      return TripointRelOmt.new(dx, dy, 0)
    end
  end
end

---@param turn TimePoint
---@return TimePoint
mod.blood_moon_evening_start_turn = function(turn)
  local day_start = turn
    - TimeDuration.from_hours(turn:hour_of_day())
    - TimeDuration.from_minutes(turn:minute_of_hour())
    - TimeDuration.from_seconds(turn:second_of_minute())

  if turn:hour_of_day() >= BLOOD_MOON_START_HOUR then
    return day_start + TimeDuration.from_hours(BLOOD_MOON_START_HOUR)
  end

  return day_start - TimeDuration.from_days(1) + TimeDuration.from_hours(BLOOD_MOON_START_HOUR)
end

---@param start_turn TimePoint
---@param end_turn TimePoint
---@param interval_turns integer
---@return integer
mod.count_turn_multiples_between = function(start_turn, end_turn, interval_turns)
  local start = start_turn:to_turn()
  local finish = end_turn:to_turn()
  if finish <= start then
    return 0
  end

  return math.floor((finish - 1) / interval_turns) - math.floor((start - 1) / interval_turns)
end

---@param turn TimePoint
---@return boolean
mod.should_spawn_hordes = function(turn)
  local spawn_pulse_interval = mod.sanitize_spawn_pulse_interval(storage.spawn_pulse_interval)
  local pulse_number = math.floor(turn:to_turn() / HORDE_TICK_INTERVAL_TURNS)
  return pulse_number % spawn_pulse_interval == 0
end

---@param start_turn TimePoint
---@return string
mod.night_spawn_estimate_text = function(start_turn)
  local dawn_turn = (start_turn + TimeDuration.from_days(1)):sunrise()
  local horde_pulses = mod.count_turn_multiples_between(
    start_turn,
    dawn_turn,
    HORDE_TICK_INTERVAL_TURNS
  )
  local spawn_pulse_interval = mod.sanitize_spawn_pulse_interval(storage.spawn_pulse_interval)
  local spawn_turn_interval = HORDE_TICK_INTERVAL_TURNS * spawn_pulse_interval
  local spawn_pulses = mod.count_turn_multiples_between(
    start_turn,
    dawn_turn,
    spawn_turn_interval
  )
  local hordes_spawned = spawn_pulses * mod.sanitize_spawned_hordes_per_tick(
    storage.spawned_hordes_per_tick
  )
  local population_each = mod.spawn_horde_population(start_turn)
  local total_population = hordes_spawned * population_each

  return string.format(
    gettext(
      "Estimated this Blood Moon night: %d horde pulse(s), %d spawn pulse(s), %d horde(s), about %d total population."
    ),
    horde_pulses,
    spawn_pulses,
    hordes_spawned,
    total_population
  )
end

---@return TimePoint
mod.next_blood_moon_start_turn = function()
  local candidate_turn = gapi.current_turn():to_turn()
  local current_turn = TimePoint.from_turn(candidate_turn)
  if mod.is_blood_moon_night(current_turn) then
    return mod.blood_moon_evening_start_turn(current_turn)
  end

  local remainder = candidate_turn % 60
  if remainder ~= 0 then
    candidate_turn = candidate_turn + 60 - remainder
  end

  while true do
    local candidate = TimePoint.from_turn(candidate_turn)
    if mod.is_blood_moon_night(candidate) then
      return candidate
    end
    candidate_turn = candidate_turn + 60
  end
end

---@return TimePoint
mod.next_blood_moon_horde_turn = function()
  local candidate_turn = gapi.current_turn():to_turn()
  local remainder = candidate_turn % HORDE_TICK_INTERVAL_TURNS
  if remainder ~= 0 then
    candidate_turn = candidate_turn + HORDE_TICK_INTERVAL_TURNS - remainder
  end

  while true do
    local candidate = TimePoint.from_turn(candidate_turn)
    if mod.is_blood_moon_night(candidate) then
      return candidate
    end
    candidate_turn = candidate_turn + HORDE_TICK_INTERVAL_TURNS
  end
end

---@return string
mod.next_horde_preview_text = function()
  local current_turn = gapi.current_turn()
  local next_start_turn = mod.next_blood_moon_start_turn()
  local next_turn = mod.next_blood_moon_horde_turn()
  local horde_preview = string.format(
    gettext("Next accelerated horde tick: horde signal %d, %d horde(s), spawn signal %d, %d population each on day %d at %s"),
    mod.current_horde_signal_power(next_turn),
    mod.sanitize_spawned_hordes_per_tick(storage.spawned_hordes_per_tick),
    mod.current_spawn_signal_power(next_turn),
    mod.spawn_horde_population(next_turn),
    mod.blood_moon_day_number(next_turn),
    tostring(next_turn)
  )

  if mod.is_blood_moon_night(current_turn) then
    return string.format(
      gettext("Blood Moon active now on day %d at %s.\nSpawn group: %s\n%s\n%s"),
      mod.blood_moon_day_number(next_start_turn),
      tostring(next_start_turn),
      mod.sanitize_group_id(storage.group_id),
      mod.night_spawn_estimate_text(next_start_turn),
      horde_preview
    )
  end

  return string.format(
    gettext("Next Blood Moon starts on day %d at %s.\nSpawn group: %s\n%s\n%s"),
    mod.blood_moon_day_number(next_start_turn),
    tostring(next_start_turn),
    mod.sanitize_group_id(storage.group_id),
    mod.night_spawn_estimate_text(next_start_turn),
    horde_preview
  )
end

---@param monster Monster
---@return boolean
mod.is_blood_moon_zombie = function(monster)
  return monster ~= nil and monster.friendly == 0 and monster:in_species(ZOMBIE_SPECIES_ID)
end

---@param monster Monster
---@param avatar_pos TripointBubMs
mod.steer_zombie_toward_player = function(monster, avatar_pos)
  if not mod.is_blood_moon_zombie(monster) then
    return
  end

  monster.anger = math.max(monster.anger, BLOOD_MOON_MONSTER_ANGER)
  monster.morale = math.max(monster.morale, BLOOD_MOON_MONSTER_MORALE)
  monster:wander_to(avatar_pos, BLOOD_MOON_MONSTER_WANDER_STRENGTH)
end

---@param avatar_sm TripointAbsSm
mod.refresh_blood_moon_hordes = function(avatar_sm)
  local surface_avatar_sm = mod.surface_sm(avatar_sm)
  local avatar_omt = mod.surface_omt(surface_avatar_sm:to_omt())
  local seen_hordes = {}

  for dx = -HORDE_TARGET_REFRESH_RADIUS_OMT, HORDE_TARGET_REFRESH_RADIUS_OMT do
    for dy = -HORDE_TARGET_REFRESH_RADIUS_OMT, HORDE_TARGET_REFRESH_RADIUS_OMT do
      local check_omt = avatar_omt + TripointRelOmt.new(dx, dy, 0)
      for _, horde in ipairs(overmapbuffer.hordes_at(check_omt)) do
        if horde.horde_behaviour == BLOOD_MOON_HORDE_BEHAVIOUR then
          local abs_pos = horde:abs_pos()
          local key = string.format("%d:%d:%d", abs_pos.x, abs_pos.y, abs_pos.z)
          if not seen_hordes[key] then
            seen_hordes[key] = true
            horde:set_target(surface_avatar_sm)
            horde:set_interest(100)
          end
        end
      end
    end
  end
end

---@param turn TimePoint
mod.spawn_hordes_around_player = function(turn)
  if not mod.should_spawn_hordes(turn) then
    return
  end

  local spawned_hordes_per_tick = mod.sanitize_spawned_hordes_per_tick(storage.spawned_hordes_per_tick)
  if spawned_hordes_per_tick <= 0 then
    return
  end

  local avatar = gapi.get_avatar()
  local avatar_sm = mod.surface_sm(avatar:global_sm_location())
  local avatar_omt = mod.surface_omt(avatar_sm:to_omt())
  local population = mod.spawn_horde_population(turn)

  for _ = 1, spawned_hordes_per_tick do
    local spawn_pos = avatar_omt + mod.random_horde_spawn_offset()
    local horde = overmapbuffer.create_horde({
      type = mod.sanitize_group_id(storage.group_id),
      pos = spawn_pos,
      radius = 1,
      population = population,
      horde = true,
      behaviour = BLOOD_MOON_HORDE_BEHAVIOUR,
      diffuse = false,
      target = avatar_omt,
    })

    if horde then
      horde:set_target(avatar_sm)
      horde:set_interest(100)
    end
  end
end

mod.on_horde_tick = function()
  local turn = gapi.current_turn()
  if not mod.is_blood_moon_night(turn) then
    return
  end

  local avatar = gapi.get_avatar()
  local avatar_sm = mod.surface_sm(avatar:global_sm_location())
  mod.spawn_hordes_around_player(turn)
  mod.refresh_blood_moon_hordes(avatar_sm)
  overmapbuffer.signal_hordes(avatar_sm, mod.current_horde_signal_power(turn))

  for _ = 1, mod.sanitize_multiplier(storage.multiplier) - 1 do
    overmapbuffer.move_hordes()
  end

  mod.refresh_blood_moon_hordes(avatar_sm)
end

mod.on_tracking_tick = function()
  if not mod.is_blood_moon_night(gapi.current_turn()) then
    return
  end

  mod.refresh_blood_moon_hordes(mod.surface_sm(gapi.get_avatar():global_sm_location()))
end

---@param params { monster: Monster }
mod.on_monster_loaded = function(params)
  if not mod.is_blood_moon_night(gapi.current_turn()) then
    return
  end

  mod.steer_zombie_toward_player(params.monster, gapi.get_avatar():get_pos_ms())
end

---@param params { monster: Monster }
mod.on_monster_spawn = function(params)
  if not mod.is_blood_moon_night(gapi.current_turn()) then
    return
  end

  mod.steer_zombie_toward_player(params.monster, gapi.get_avatar():get_pos_ms())
end

---@param params { monster: Monster, from: TripointBubMs, to: TripointBubMs, force: boolean }
mod.on_monster_try_move = function(params)
  if not mod.is_blood_moon_night(gapi.current_turn()) then
    return
  end

  mod.steer_zombie_toward_player(params.monster, gapi.get_avatar():get_pos_ms())
end

mod.sync_active_state = function()
  mod.active = mod.is_blood_moon_night(gapi.current_turn())
end

mod.on_game_started = function()
  mod.sync_active_state()
end

mod.on_game_load = function()
  mod.sync_active_state()
end

mod.announce_transition = function()
  local is_active = mod.is_blood_moon_night(gapi.current_turn())
  if mod.active == nil then
    mod.active = is_active
    return
  end

  if is_active == mod.active then
    return
  end

  mod.active = is_active
  if is_active then
    gapi.add_msg(
      MsgType.bad,
      mod.random_message(BLOOD_MOON_START_MESSAGES)
    )
  else
    gapi.add_msg(
      MsgType.bad,
      mod.random_message(BLOOD_MOON_END_MESSAGES)
    )
  end
end

---@param title string
---@param description string
---@return integer?
mod.prompt_setting = function(title, description)
  local prompt = PopupInputStr.new()
  prompt:desc(description)
  prompt:title(title)

  local value = prompt:query_int()
  if value < 0 then
    return nil
  end

  return value
end

---@param title string
---@param description string
---@return string?
mod.prompt_string_setting = function(title, description)
  local prompt = PopupInputStr.new()
  prompt:desc(description)
  prompt:title(title)

  local value = prompt:query_str()
  if value == nil then
    return nil
  end

  local trimmed = value:match("^%s*(.-)%s*$")
  if trimmed == "" then
    return nil
  end

  return trimmed
end

mod.configure_interval = function()
  while true do
    local menu = UiList.new()
    menu:title(gettext("Configure Blood Moon"))
    menu:text(mod.next_horde_preview_text())
    menu:add_w_desc(
      1,
      string.format(gettext("Interval: %d days"), mod.sanitize_interval(storage.interval_days)),
      gettext("How often a Blood Moon happens.  7 means one Blood Moon every 7 days.")
    )
    menu:add_w_desc(
      2,
      string.format(gettext("Multiplier: %dx"), mod.sanitize_multiplier(storage.multiplier)),
      gettext("How many extra accelerated horde updates run during a Blood Moon.  Higher values make hordes react faster.")
    )
    menu:add_w_desc(
      3,
      string.format(
        gettext("Horde signal strength: %d"),
        mod.sanitize_signal_power(storage.horde_signal_power)
      ),
      gettext("Base attraction strength used to pull overmap hordes toward you during a Blood Moon.")
    )
    menu:add_w_desc(
      4,
      string.format(
        gettext("Horde growth days: %d"),
        mod.sanitize_days_per_signal_growth(storage.horde_days_per_signal_growth)
      ),
      gettext("How many days must pass before horde signal strength increases by 1.")
    )
    menu:add_w_desc(
      5,
      string.format(
        gettext("Horde max growth: %d"),
        mod.sanitize_max_signal_growth(storage.horde_max_signal_growth)
      ),
      gettext("Maximum bonus that can be added to horde signal strength from time-based growth.")
    )
    menu:add_w_desc(
      6,
      string.format(
        gettext("Spawn signal strength: %d"),
        mod.sanitize_signal_power(storage.spawn_signal_power)
      ),
      gettext("Base strength used only to scale the size of newly spawned hordes.  It does not affect horde attraction.")
    )
    menu:add_w_desc(
      7,
      string.format(
        gettext("Spawn growth days: %d"),
        mod.sanitize_days_per_signal_growth(storage.spawn_days_per_signal_growth)
      ),
      gettext("How many days must pass before spawned horde size scaling gains +1 signal strength.")
    )
    menu:add_w_desc(
      8,
      string.format(
        gettext("Spawn max growth: %d"),
        mod.sanitize_max_signal_growth(storage.spawn_max_signal_growth)
      ),
      gettext("Maximum bonus that can be added to spawned horde size scaling from time-based growth.")
    )
    menu:add_w_desc(
      9,
      string.format(
        gettext("Spawned hordes/tick: %d"),
        mod.sanitize_spawned_hordes_per_tick(storage.spawned_hordes_per_tick)
      ),
      gettext("How many new hordes are spawned around you each time a spawn pulse triggers.")
    )
    menu:add_w_desc(
      10,
      string.format(
        gettext("Population/strength: %d"),
        mod.sanitize_population_per_signal(storage.population_per_signal)
      ),
      gettext("How many zombies each point of current spawn signal strength adds to every spawned horde.")
    )
    menu:add_w_desc(
      11,
      string.format(
        gettext("Spawn pulse interval: %d"),
        mod.sanitize_spawn_pulse_interval(storage.spawn_pulse_interval)
      ),
      gettext("How many accelerated horde pulses pass between new horde spawns.  1 means every pulse.")
    )
    menu:add_w_desc(
      12,
      string.format(
        gettext("Spawn group: %s"),
        mod.sanitize_group_id(storage.group_id)
      ),
      gettext("Monster group ID used for newly spawned Blood Moon hordes, such as GROUP_ZOMBIE.")
    )

    local choice = menu:query()
    if choice < 0 then
      return
    end

    if choice == 1 then
      local interval_days = mod.prompt_setting(
        gettext("Blood Moon interval: "),
        string.format(
          gettext("Set how many days pass between Blood Moons.\nCurrent: %d\nDefault: %d"),
          mod.sanitize_interval(storage.interval_days),
          DEFAULT_INTERVAL_DAYS
        )
      )
      if interval_days and interval_days > 0 then
        mod.set_interval(interval_days)
        ui.popup(string.format(gettext("Blood Moon interval set to %d days."), storage.interval_days))
      end
    elseif choice == 2 then
      local multiplier = mod.prompt_setting(
        gettext("Blood Moon multiplier: "),
        string.format(
          gettext("Set how many accelerated horde updates run during a Blood Moon.\nCurrent: %d\nDefault: %d"),
          mod.sanitize_multiplier(storage.multiplier),
          DEFAULT_MULTIPLIER
        )
      )
      if multiplier and multiplier > 0 then
        mod.set_multiplier(multiplier)
        ui.popup(string.format(gettext("Blood Moon multiplier set to %dx."), storage.multiplier))
      end
    elseif choice == 3 then
      local horde_signal_power = mod.prompt_setting(
        gettext("Blood Moon horde signal strength: "),
        string.format(
          gettext("Set the base attraction strength used to pull overmap hordes toward you.\nCurrent: %d\nDefault: %d"),
          mod.sanitize_signal_power(storage.horde_signal_power),
          DEFAULT_HORDE_SIGNAL_POWER
        )
      )
      if horde_signal_power and horde_signal_power >= 0 then
        mod.set_horde_signal_power(horde_signal_power)
        ui.popup(
          string.format(
            gettext("Blood Moon horde signal strength set to %d."),
            storage.horde_signal_power
          )
        )
      end
    elseif choice == 4 then
      local horde_days_per_signal_growth = mod.prompt_setting(
        gettext("Blood Moon horde growth days: "),
        string.format(
          gettext("Set how many days it takes for horde signal strength to gain +1.\nCurrent: %d\nDefault: %d"),
          mod.sanitize_days_per_signal_growth(storage.horde_days_per_signal_growth),
          DEFAULT_HORDE_DAYS_PER_SIGNAL_GROWTH
        )
      )
      if horde_days_per_signal_growth and horde_days_per_signal_growth > 0 then
        mod.set_horde_days_per_signal_growth(horde_days_per_signal_growth)
        ui.popup(
          string.format(
            gettext("Blood Moon horde days per signal growth set to %d."),
            storage.horde_days_per_signal_growth
          )
        )
      end
    elseif choice == 5 then
      local horde_max_signal_growth = mod.prompt_setting(
        gettext("Blood Moon horde max growth: "),
        string.format(
          gettext("Set the maximum bonus that elapsed time can add to horde signal strength.\nCurrent: %d\nDefault: %d"),
          mod.sanitize_max_signal_growth(storage.horde_max_signal_growth),
          DEFAULT_HORDE_MAX_SIGNAL_GROWTH
        )
      )
      if horde_max_signal_growth and horde_max_signal_growth >= 0 then
        mod.set_horde_max_signal_growth(horde_max_signal_growth)
        ui.popup(
          string.format(
            gettext("Blood Moon horde max signal growth set to %d."),
            storage.horde_max_signal_growth
          )
        )
      end
    elseif choice == 6 then
      local spawn_signal_power = mod.prompt_setting(
        gettext("Blood Moon spawn signal strength: "),
        string.format(
          gettext("Set the base strength used to scale spawned horde size.  This does not affect horde attraction.\nCurrent: %d\nDefault: %d"),
          mod.sanitize_signal_power(storage.spawn_signal_power),
          DEFAULT_SPAWN_SIGNAL_POWER
        )
      )
      if spawn_signal_power and spawn_signal_power >= 0 then
        mod.set_spawn_signal_power(spawn_signal_power)
        ui.popup(
          string.format(
            gettext("Blood Moon spawn signal strength set to %d."),
            storage.spawn_signal_power
          )
        )
      end
    elseif choice == 7 then
      local spawn_days_per_signal_growth = mod.prompt_setting(
        gettext("Blood Moon spawn growth days: "),
        string.format(
          gettext("Set how many days it takes for spawned horde size scaling to gain +1 signal strength.\nCurrent: %d\nDefault: %d"),
          mod.sanitize_days_per_signal_growth(storage.spawn_days_per_signal_growth),
          DEFAULT_SPAWN_DAYS_PER_SIGNAL_GROWTH
        )
      )
      if spawn_days_per_signal_growth and spawn_days_per_signal_growth > 0 then
        mod.set_spawn_days_per_signal_growth(spawn_days_per_signal_growth)
        ui.popup(
          string.format(
            gettext("Blood Moon spawn days per signal growth set to %d."),
            storage.spawn_days_per_signal_growth
          )
        )
      end
    elseif choice == 8 then
      local spawn_max_signal_growth = mod.prompt_setting(
        gettext("Blood Moon spawn max growth: "),
        string.format(
          gettext("Set the maximum bonus that elapsed time can add to spawned horde size scaling.\nCurrent: %d\nDefault: %d"),
          mod.sanitize_max_signal_growth(storage.spawn_max_signal_growth),
          DEFAULT_SPAWN_MAX_SIGNAL_GROWTH
        )
      )
      if spawn_max_signal_growth and spawn_max_signal_growth >= 0 then
        mod.set_spawn_max_signal_growth(spawn_max_signal_growth)
        ui.popup(
          string.format(
            gettext("Blood Moon spawn max signal growth set to %d."),
            storage.spawn_max_signal_growth
          )
        )
      end
    elseif choice == 9 then
      local spawned_hordes_per_tick = mod.prompt_setting(
        gettext("Blood Moon spawned hordes/tick: "),
        string.format(
          gettext("Set how many new hordes are spawned each time a spawn pulse triggers.\nCurrent: %d\nDefault: %d"),
          mod.sanitize_spawned_hordes_per_tick(storage.spawned_hordes_per_tick),
          DEFAULT_SPAWNED_HORDES_PER_TICK
        )
      )
      if spawned_hordes_per_tick and spawned_hordes_per_tick >= 0 then
        mod.set_spawned_hordes_per_tick(spawned_hordes_per_tick)
        ui.popup(
          string.format(
            gettext("Blood Moon spawned hordes per tick set to %d."),
            storage.spawned_hordes_per_tick
          )
        )
      end
    elseif choice == 10 then
      local population_per_signal = mod.prompt_setting(
        gettext("Blood Moon population/strength: "),
        string.format(
          gettext("Set how many zombies each point of current spawn signal strength adds to every spawned horde.\nCurrent: %d\nDefault: %d"),
          mod.sanitize_population_per_signal(storage.population_per_signal),
          DEFAULT_POPULATION_PER_SIGNAL
        )
      )
      if population_per_signal and population_per_signal > 0 then
        mod.set_population_per_signal(population_per_signal)
        ui.popup(
          string.format(
            gettext("Blood Moon population per signal set to %d."),
            storage.population_per_signal
          )
        )
      end
    elseif choice == 11 then
      local spawn_pulse_interval = mod.prompt_setting(
        gettext("Blood Moon spawn pulse interval: "),
        string.format(
          gettext("Set how many accelerated horde pulses pass between new horde spawns.  1 means every pulse.\nCurrent: %d\nDefault: %d"),
          mod.sanitize_spawn_pulse_interval(storage.spawn_pulse_interval),
          DEFAULT_SPAWN_PULSE_INTERVAL
        )
      )
      if spawn_pulse_interval and spawn_pulse_interval > 0 then
        mod.set_spawn_pulse_interval(spawn_pulse_interval)
        ui.popup(
          string.format(
            gettext("Blood Moon spawn pulse interval set to %d."),
            storage.spawn_pulse_interval
          )
        )
      end
    elseif choice == 12 then
      local group_id = mod.prompt_string_setting(
        gettext("Blood Moon spawn group: "),
        string.format(
          gettext("Set the monster group ID used for newly spawned Blood Moon hordes.\nCurrent: %s\nDefault: %s"),
          mod.sanitize_group_id(storage.group_id),
          HORDE_GROUP_ID
        )
      )
      if group_id then
        mod.set_group_id(group_id)
        ui.popup(
          string.format(
            gettext("Blood Moon spawn group set to %s."),
            storage.group_id
          )
        )
      end
    end
  end
end

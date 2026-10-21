local constants = require("./blood_moon_constants")
local gettext = locale.gettext
local schedule = {}

---@param message string
local function wrap_warning(message)
  local lines = {}
  local line = ""
  for word in message:gmatch("%S+") do
    if line ~= "" and #line + #word + 1 > 72 then
      lines[#lines + 1] = line
      line = word
    else
      line = line == "" and word or line .. " " .. word
    end
  end
  if line ~= "" then lines[#lines + 1] = line end
  return table.concat(lines, "\n")
end

---@param mod ModBloodMoon
---@param storage BloodMoonStorage
schedule.register = function(mod, storage)
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

  ---@param messages string[]
  ---@return string
  mod.random_message = function(messages) return messages[gapi.rng(1, #messages)] end

  ---@param turn TimePoint
  ---@return integer
  mod.blood_moon_day_number = function(turn)
    -- Compare calendar days so a morning start still advances at midnight.
    if storage.start_day == nil then storage.start_day = (gapi.current_turn() - gapi.turn_zero()):to_days() end
    return (turn - gapi.turn_zero()):to_days() - storage.start_day + 1
  end

  ---@param turn TimePoint
  ---@return boolean
  mod.is_blood_moon_night = function(turn)
    local start_turn = mod.blood_moon_evening_start_turn(turn)
    local day_number = mod.blood_moon_day_number(start_turn)
    local interval_days = mod.sanitize_interval(storage.interval_days)
    if day_number < 1 or day_number % interval_days ~= 0 then return false end

    local dawn_turn = (start_turn + TimeDuration.from_days(1)):sunrise()
    return turn >= start_turn and turn < dawn_turn
  end

  ---@param turn TimePoint
  ---@return TimePoint
  mod.blood_moon_evening_start_turn = function(turn)
    local day_start = turn
      - TimeDuration.from_hours(turn:hour_of_day())
      - TimeDuration.from_minutes(turn:minute_of_hour())
      - TimeDuration.from_seconds(turn:second_of_minute())

    if turn:hour_of_day() >= constants.BLOOD_MOON_START_HOUR then
      return day_start + TimeDuration.from_hours(constants.BLOOD_MOON_START_HOUR)
    end

    return day_start - TimeDuration.from_days(1) + TimeDuration.from_hours(constants.BLOOD_MOON_START_HOUR)
  end

  ---@param start_turn TimePoint
  ---@param end_turn TimePoint
  ---@param interval_turns integer
  ---@return integer
  mod.count_turn_multiples_between = function(start_turn, end_turn, interval_turns)
    local start = start_turn:to_turn()
    local finish = end_turn:to_turn()
    if finish <= start then return 0 end

    return math.floor((finish - 1) / interval_turns) - math.floor((start - 1) / interval_turns)
  end

  ---@param start_turn TimePoint
  ---@return string
  mod.night_spawn_estimate_text = function(start_turn)
    local dawn_turn = (start_turn + TimeDuration.from_days(1)):sunrise()
    local horde_pulses = mod.count_turn_multiples_between(start_turn, dawn_turn, constants.HORDE_TICK_INTERVAL_TURNS)
    local spawn_pulse_interval = mod.sanitize_spawn_pulse_interval(storage.spawn_pulse_interval)
    local spawn_turn_interval = constants.HORDE_TICK_INTERVAL_TURNS * spawn_pulse_interval
    local spawn_pulses = mod.count_turn_multiples_between(start_turn, dawn_turn, spawn_turn_interval)
    local hordes_spawned = spawn_pulses * mod.sanitize_spawned_hordes_per_tick(storage.spawned_hordes_per_tick)
    local population_each = mod.spawn_horde_population(start_turn)
    local total_population = hordes_spawned * population_each

    return string.format(
      gettext(
        "Estimated this Blood Moon night: %d horde pulse(s), %d horde spawn pulse(s), %d new horde(s), about %d additional population.  Existing hordes are not included."
      ),
      horde_pulses,
      spawn_pulses,
      hordes_spawned,
      total_population
    )
  end

  ---@return TimePoint
  mod.next_blood_moon_start_turn = function()
    local turn = gapi.current_turn()
    local start_turn = mod.blood_moon_evening_start_turn(turn)
    if mod.is_blood_moon_night(turn) then return start_turn end

    start_turn = start_turn + TimeDuration.from_days(1)
    local day_number = mod.blood_moon_day_number(start_turn)
    local interval_days = mod.sanitize_interval(storage.interval_days)
    local days_until = (interval_days - day_number % interval_days) % interval_days
    return start_turn + TimeDuration.from_days(days_until)
  end

  ---@return TimePoint
  mod.next_blood_moon_horde_turn = function()
    local candidate_turn = gapi.current_turn():to_turn()
    local remainder = candidate_turn % constants.HORDE_TICK_INTERVAL_TURNS
    if remainder ~= 0 then candidate_turn = candidate_turn + constants.HORDE_TICK_INTERVAL_TURNS - remainder end

    while true do
      local candidate = TimePoint.from_turn(candidate_turn)
      if mod.is_blood_moon_night(candidate) then return candidate end
      candidate_turn = candidate_turn + constants.HORDE_TICK_INTERVAL_TURNS
    end
  end

  ---@return string
  mod.next_horde_preview_text = function()
    local current_turn = gapi.current_turn()
    local next_start_turn = mod.next_blood_moon_start_turn()
    local next_turn = mod.next_blood_moon_horde_turn()
    local horde_preview = string.format(
      gettext("Next accelerated horde tick: horde signal %d on day %d at %s"),
      mod.current_horde_signal_power(next_turn),
      mod.blood_moon_day_number(next_turn),
      tostring(next_turn)
    )
    horde_preview = horde_preview
      .. "\n"
      .. string.format(
        gettext("Horde spawns per pulse: %d new horde(s), spawn signal %d, %d population per new horde."),
        mod.sanitize_spawned_hordes_per_tick(storage.spawned_hordes_per_tick),
        mod.current_spawn_signal_power(next_turn),
        mod.spawn_horde_population(next_turn)
      )

    if mod.is_blood_moon_night(current_turn) then
      return string.format(
        gettext("Blood Moon active now on day %d at %s.\nHorde spawn group: %s\n%s\n%s"),
        mod.blood_moon_day_number(next_start_turn),
        tostring(next_start_turn),
        mod.sanitize_group_id(storage.group_id),
        mod.night_spawn_estimate_text(next_start_turn),
        horde_preview
      )
    end

    return string.format(
      gettext("Next Blood Moon starts on day %d at %s.\nHorde spawn group: %s\n%s\n%s"),
      mod.blood_moon_day_number(next_start_turn),
      tostring(next_start_turn),
      mod.sanitize_group_id(storage.group_id),
      mod.night_spawn_estimate_text(next_start_turn),
      horde_preview
    )
  end

  mod.sync_active_state = function() mod.active = mod.is_blood_moon_night(gapi.current_turn()) end

  mod.on_game_started = function()
    storage.start_day = (gapi.current_turn() - gapi.turn_zero()):to_days()
    mod.sync_active_state()
    mod.warn_upcoming_blood_moon()
  end

  mod.on_game_load = function()
    mod.sync_active_state()
    mod.warn_upcoming_blood_moon()
  end

  --- Warn once per scheduled night, including when loading during the warning window.
  mod.warn_upcoming_blood_moon = function()
    local turn = gapi.current_turn()
    local start_turn = mod.next_blood_moon_start_turn()
    if turn >= start_turn or turn < start_turn - TimeDuration.from_hours(12) then return end
    if storage.last_warned_start_turn == start_turn:to_turn() then return end

    storage.last_warned_start_turn = start_turn:to_turn()
    local message = gettext(
      "The sun has taken on a dull orange glow, as though something vast is passing between it and the earth.  The shadows seem darker than they should.  You have a terrible feeling that tonight, the dead will find you."
    )
    gapi.add_msg(MsgType.warning, message)
    local warning = UiList.new()
    warning:text(wrap_warning(message))
    warning:text_color(Color.c_yellow)
    warning:add(1, gettext("Confirm"))
    warning:query()
  end

  mod.announce_transition = function()
    mod.warn_upcoming_blood_moon()
    local is_active = mod.is_blood_moon_night(gapi.current_turn())
    if mod.active == nil then
      mod.active = is_active
      return
    end

    if is_active == mod.active then return end

    mod.active = is_active
    if is_active then
      gapi.add_msg(MsgType.bad, mod.random_message(BLOOD_MOON_START_MESSAGES))
    else
      gapi.add_msg(MsgType.bad, mod.random_message(BLOOD_MOON_END_MESSAGES))
    end
  end
end

return schedule

local constants = require("./blood_moon_constants")
local hordes = {}

---@param mod ModBloodMoon
---@param storage BloodMoonStorage
hordes.register = function(mod, storage)
  local ZOMBIE_SPECIES_ID = SpeciesTypeId.new("ZOMBIE")

  ---@param params { results: { target: TripointAbsSm, interest: integer } }
  game.horde_behaviours[constants.BLOOD_MOON_HORDE_BEHAVIOUR] = function(params)
    params.results.target = mod.surface_sm(gapi.get_avatar():global_sm_location())
    params.results.interest = 100
  end

  ---@param pos TripointAbsOmt
  ---@return TripointAbsOmt
  mod.surface_omt = function(pos) return TripointAbsOmt.new(pos.x, pos.y, 0) end

  ---@param pos TripointAbsSm
  ---@return TripointAbsSm
  mod.surface_sm = function(pos) return TripointAbsSm.new(pos.x, pos.y, 0) end

  ---@return integer
  mod.min_spawn_distance_omt = function()
    local map = gapi.get_map()
    if map == nil or type(map.get_map_size_in_submaps) ~= "function" then
      return constants.HORDE_FALLBACK_MIN_SPAWN_DISTANCE_OMT
    end
    local half_size_submaps = math.floor(map:get_map_size_in_submaps() / 2)
    local loaded_radius_omt = math.ceil((half_size_submaps + 1) / 2)
    return loaded_radius_omt + constants.HORDE_SPAWN_DISTANCE_BUFFER_OMT
  end

  ---@return integer
  mod.max_spawn_distance_omt = function() return mod.min_spawn_distance_omt() + constants.HORDE_SPAWN_RING_WIDTH_OMT end

  mod.active = nil

  ---@param turn TimePoint
  ---@param options BloodMoonSignalGrowthOptions
  ---@return integer
  mod.current_scaled_signal_power = function(turn, options)
    local elapsed_days = math.max(0, mod.blood_moon_day_number(turn) - 1)
    local sanitized_signal_power = mod.sanitize_signal_power(options.base_signal_power)
    local sanitized_days_per_signal_growth = mod.sanitize_days_per_signal_growth(options.days_per_signal_growth)
    local sanitized_max_signal_growth = mod.sanitize_max_signal_growth(options.max_signal_growth)
    local signal_growth =
      math.min(math.floor(elapsed_days / sanitized_days_per_signal_growth), sanitized_max_signal_growth)
    return sanitized_signal_power + signal_growth
  end

  ---@param turn TimePoint
  ---@return integer
  mod.current_horde_signal_power = function(turn)
    return mod.current_scaled_signal_power(turn, {
      base_signal_power = storage.horde_signal_power,
      days_per_signal_growth = storage.horde_days_per_signal_growth,
      max_signal_growth = storage.horde_max_signal_growth,
    })
  end

  ---@param turn TimePoint
  ---@return integer
  mod.current_spawn_signal_power = function(turn)
    return mod.current_scaled_signal_power(turn, {
      base_signal_power = storage.spawn_signal_power,
      days_per_signal_growth = storage.spawn_days_per_signal_growth,
      max_signal_growth = storage.spawn_max_signal_growth,
    })
  end

  ---@param turn TimePoint
  ---@return integer
  mod.spawn_horde_population = function(turn)
    local spawn_signal_power = mod.current_spawn_signal_power(turn)
    return spawn_signal_power * mod.sanitize_population_per_signal(storage.population_per_signal)
  end

  ---@param turn TimePoint
  ---@return integer
  mod.current_signal_power = function(turn) return mod.current_horde_signal_power(turn) end

  ---@return TripointRelOmt
  mod.random_horde_spawn_offset = function()
    local min_spawn_distance = mod.min_spawn_distance_omt()
    local max_spawn_distance = mod.max_spawn_distance_omt()
    while true do
      local dx = gapi.rng(-max_spawn_distance, max_spawn_distance)
      local dy = gapi.rng(-max_spawn_distance, max_spawn_distance)
      local distance = math.max(math.abs(dx), math.abs(dy))
      if distance >= min_spawn_distance and distance <= max_spawn_distance then return TripointRelOmt.new(dx, dy, 0) end
    end
  end

  ---@param turn TimePoint
  ---@return boolean
  mod.should_spawn_hordes = function(turn)
    local spawn_pulse_interval = mod.sanitize_spawn_pulse_interval(storage.spawn_pulse_interval)
    local pulse_number = math.floor(turn:to_turn() / constants.HORDE_TICK_INTERVAL_TURNS)
    return pulse_number % spawn_pulse_interval == 0
  end

  ---@param monster Monster
  ---@return boolean
  mod.is_blood_moon_zombie =
    function(monster) return monster ~= nil and monster.friendly == 0 and monster:in_species(ZOMBIE_SPECIES_ID) end

  ---@param monster Monster
  ---@param avatar_pos TripointBubMs
  mod.steer_zombie_toward_player = function(monster, avatar_pos)
    if not mod.is_blood_moon_zombie(monster) then return end

    monster.anger = math.max(monster.anger, constants.BLOOD_MOON_MONSTER_ANGER)
    monster.morale = math.max(monster.morale, constants.BLOOD_MOON_MONSTER_MORALE)
    monster:wander_to(avatar_pos, constants.BLOOD_MOON_MONSTER_WANDER_STRENGTH)
  end

  ---@param avatar_sm TripointAbsSm
  mod.refresh_blood_moon_hordes = function(avatar_sm)
    local surface_avatar_sm = mod.surface_sm(avatar_sm)
    local avatar_omt = mod.surface_omt(surface_avatar_sm:to_omt())
    local seen_hordes = {}

    for dx = -constants.HORDE_TARGET_REFRESH_RADIUS_OMT, constants.HORDE_TARGET_REFRESH_RADIUS_OMT do
      for dy = -constants.HORDE_TARGET_REFRESH_RADIUS_OMT, constants.HORDE_TARGET_REFRESH_RADIUS_OMT do
        local check_omt = avatar_omt + TripointRelOmt.new(dx, dy, 0)
        for _, horde in ipairs(overmapbuffer.hordes_at(check_omt)) do
          if horde.horde_behaviour == constants.BLOOD_MOON_HORDE_BEHAVIOUR then
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
    if not mod.should_spawn_hordes(turn) then return end

    local spawned_hordes_per_tick = mod.sanitize_spawned_hordes_per_tick(storage.spawned_hordes_per_tick)
    if spawned_hordes_per_tick <= 0 then return end

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
        behaviour = constants.BLOOD_MOON_HORDE_BEHAVIOUR,
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
    if not mod.is_blood_moon_night(turn) then return end

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
    if not mod.is_blood_moon_night(gapi.current_turn()) then return end

    mod.refresh_blood_moon_hordes(mod.surface_sm(gapi.get_avatar():global_sm_location()))
  end

  ---@param params { monster: Monster }
  mod.on_monster_loaded = function(params)
    if not mod.is_blood_moon_night(gapi.current_turn()) then return end

    mod.steer_zombie_toward_player(params.monster, gapi.get_avatar():get_pos_ms())
  end

  ---@param params { monster: Monster }
  mod.on_monster_spawn = function(params)
    if not mod.is_blood_moon_night(gapi.current_turn()) then return end

    mod.steer_zombie_toward_player(params.monster, gapi.get_avatar():get_pos_ms())
  end

  ---@param params { monster: Monster, from: TripointBubMs, to: TripointBubMs, force: boolean }
  mod.on_monster_try_move = function(params)
    if not mod.is_blood_moon_night(gapi.current_turn()) then return end

    mod.steer_zombie_toward_player(params.monster, gapi.get_avatar():get_pos_ms())
  end
end

return hordes

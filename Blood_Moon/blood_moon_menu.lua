local constants = require("./blood_moon_constants")
local ui = require("lib.ui")
local gettext = locale.gettext
local menu = {}

---@param mod ModBloodMoon
---@param storage BloodMoonStorage
menu.register = function(mod, storage)
  ---@param title string
  ---@param description string
  ---@return integer?
  mod.prompt_setting = function(title, description)
    local prompt = PopupInputStr.new()
    prompt:desc(description)
    prompt:title(title)

    local value = prompt:query_int()
    if value < 0 then return nil end

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
    if value == nil then return nil end

    local trimmed = value:match("^%s*(.-)%s*$")
    if trimmed == "" then return nil end

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
        gettext(
          "How many extra accelerated horde updates run during a Blood Moon.  Higher values make hordes react faster."
        )
      )
      menu:add_w_desc(
        3,
        string.format(gettext("Horde signal strength: %d"), mod.sanitize_signal_power(storage.horde_signal_power)),
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
        string.format(gettext("Horde max growth: %d"), mod.sanitize_max_signal_growth(storage.horde_max_signal_growth)),
        gettext("Maximum bonus that can be added to horde signal strength from time-based growth.")
      )
      menu:add_w_desc(
        6,
        string.format(gettext("Spawn signal strength: %d"), mod.sanitize_signal_power(storage.spawn_signal_power)),
        gettext(
          "Base strength used only to scale the size of newly spawned hordes.  It does not affect horde attraction."
        )
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
        string.format(gettext("Spawn max growth: %d"), mod.sanitize_max_signal_growth(storage.spawn_max_signal_growth)),
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
        string.format(gettext("Spawn group: %s"), mod.sanitize_group_id(storage.group_id)),
        gettext("Monster group ID used for newly spawned Blood Moon hordes, such as GROUP_ZOMBIE.")
      )

      local choice = menu:query()
      if choice < 0 then return end

      if choice == 1 then
        local interval_days = mod.prompt_setting(
          gettext("Blood Moon interval: "),
          string.format(
            gettext("Set how many days pass between Blood Moons.\nCurrent: %d\nDefault: %d"),
            mod.sanitize_interval(storage.interval_days),
            constants.DEFAULT_INTERVAL_DAYS
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
            constants.DEFAULT_MULTIPLIER
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
            gettext(
              "Set the base attraction strength used to pull overmap hordes toward you.\nCurrent: %d\nDefault: %d"
            ),
            mod.sanitize_signal_power(storage.horde_signal_power),
            constants.DEFAULT_HORDE_SIGNAL_POWER
          )
        )
        if horde_signal_power and horde_signal_power >= 0 then
          mod.set_horde_signal_power(horde_signal_power)
          ui.popup(string.format(gettext("Blood Moon horde signal strength set to %d."), storage.horde_signal_power))
        end
      elseif choice == 4 then
        local horde_days_per_signal_growth = mod.prompt_setting(
          gettext("Blood Moon horde growth days: "),
          string.format(
            gettext("Set how many days it takes for horde signal strength to gain +1.\nCurrent: %d\nDefault: %d"),
            mod.sanitize_days_per_signal_growth(storage.horde_days_per_signal_growth),
            constants.DEFAULT_HORDE_DAYS_PER_SIGNAL_GROWTH
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
            gettext(
              "Set the maximum bonus that elapsed time can add to horde signal strength.\nCurrent: %d\nDefault: %d"
            ),
            mod.sanitize_max_signal_growth(storage.horde_max_signal_growth),
            constants.DEFAULT_HORDE_MAX_SIGNAL_GROWTH
          )
        )
        if horde_max_signal_growth and horde_max_signal_growth >= 0 then
          mod.set_horde_max_signal_growth(horde_max_signal_growth)
          ui.popup(
            string.format(gettext("Blood Moon horde max signal growth set to %d."), storage.horde_max_signal_growth)
          )
        end
      elseif choice == 6 then
        local spawn_signal_power = mod.prompt_setting(
          gettext("Blood Moon spawn signal strength: "),
          string.format(
            gettext(
              "Set the base strength used to scale spawned horde size.  This does not affect horde attraction.\nCurrent: %d\nDefault: %d"
            ),
            mod.sanitize_signal_power(storage.spawn_signal_power),
            constants.DEFAULT_SPAWN_SIGNAL_POWER
          )
        )
        if spawn_signal_power and spawn_signal_power >= 0 then
          mod.set_spawn_signal_power(spawn_signal_power)
          ui.popup(string.format(gettext("Blood Moon spawn signal strength set to %d."), storage.spawn_signal_power))
        end
      elseif choice == 7 then
        local spawn_days_per_signal_growth = mod.prompt_setting(
          gettext("Blood Moon spawn growth days: "),
          string.format(
            gettext(
              "Set how many days it takes for spawned horde size scaling to gain +1 signal strength.\nCurrent: %d\nDefault: %d"
            ),
            mod.sanitize_days_per_signal_growth(storage.spawn_days_per_signal_growth),
            constants.DEFAULT_SPAWN_DAYS_PER_SIGNAL_GROWTH
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
            gettext(
              "Set the maximum bonus that elapsed time can add to spawned horde size scaling.\nCurrent: %d\nDefault: %d"
            ),
            mod.sanitize_max_signal_growth(storage.spawn_max_signal_growth),
            constants.DEFAULT_SPAWN_MAX_SIGNAL_GROWTH
          )
        )
        if spawn_max_signal_growth and spawn_max_signal_growth >= 0 then
          mod.set_spawn_max_signal_growth(spawn_max_signal_growth)
          ui.popup(
            string.format(gettext("Blood Moon spawn max signal growth set to %d."), storage.spawn_max_signal_growth)
          )
        end
      elseif choice == 9 then
        local spawned_hordes_per_tick = mod.prompt_setting(
          gettext("Blood Moon spawned hordes/tick: "),
          string.format(
            gettext("Set how many new hordes are spawned each time a spawn pulse triggers.\nCurrent: %d\nDefault: %d"),
            mod.sanitize_spawned_hordes_per_tick(storage.spawned_hordes_per_tick),
            constants.DEFAULT_SPAWNED_HORDES_PER_TICK
          )
        )
        if spawned_hordes_per_tick and spawned_hordes_per_tick >= 0 then
          mod.set_spawned_hordes_per_tick(spawned_hordes_per_tick)
          ui.popup(
            string.format(gettext("Blood Moon spawned hordes per tick set to %d."), storage.spawned_hordes_per_tick)
          )
        end
      elseif choice == 10 then
        local population_per_signal = mod.prompt_setting(
          gettext("Blood Moon population/strength: "),
          string.format(
            gettext(
              "Set how many zombies each point of current spawn signal strength adds to every spawned horde.\nCurrent: %d\nDefault: %d"
            ),
            mod.sanitize_population_per_signal(storage.population_per_signal),
            constants.DEFAULT_POPULATION_PER_SIGNAL
          )
        )
        if population_per_signal and population_per_signal > 0 then
          mod.set_population_per_signal(population_per_signal)
          ui.popup(string.format(gettext("Blood Moon population per signal set to %d."), storage.population_per_signal))
        end
      elseif choice == 11 then
        local spawn_pulse_interval = mod.prompt_setting(
          gettext("Blood Moon spawn pulse interval: "),
          string.format(
            gettext(
              "Set how many accelerated horde pulses pass between new horde spawns.  1 means every pulse.\nCurrent: %d\nDefault: %d"
            ),
            mod.sanitize_spawn_pulse_interval(storage.spawn_pulse_interval),
            constants.DEFAULT_SPAWN_PULSE_INTERVAL
          )
        )
        if spawn_pulse_interval and spawn_pulse_interval > 0 then
          mod.set_spawn_pulse_interval(spawn_pulse_interval)
          ui.popup(string.format(gettext("Blood Moon spawn pulse interval set to %d."), storage.spawn_pulse_interval))
        end
      elseif choice == 12 then
        local group_id = mod.prompt_string_setting(
          gettext("Blood Moon spawn group: "),
          string.format(
            gettext("Set the monster group ID used for newly spawned Blood Moon hordes.\nCurrent: %s\nDefault: %s"),
            mod.sanitize_group_id(storage.group_id),
            constants.HORDE_GROUP_ID
          )
        )
        if group_id then
          mod.set_group_id(group_id)
          ui.popup(string.format(gettext("Blood Moon spawn group set to %s."), storage.group_id))
        end
      end
    end
  end
end

return menu

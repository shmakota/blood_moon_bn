local ui = require("lib.ui")
local clock = {}

---@param mod ModBloodMoon
---@param storage BloodMoonStorage
clock.register = function(mod, storage)
  ---@return string
  mod.blood_moon_countdown_text = function()
    local turn = gapi.current_turn()
    local start_turn = mod.next_blood_moon_start_turn()
    local active = mod.is_blood_moon_night(turn)
    if active then start_turn = start_turn + TimeDuration.from_days(mod.sanitize_interval(storage.interval_days)) end

    local remaining = math.max(0, (start_turn - turn):to_seconds())
    local days = math.floor(remaining / 86400)
    local hours = math.floor(remaining / 3600) % 24
    local minutes = math.floor(remaining / 60) % 60
    local seconds = remaining % 60
    local message = string.format(
      locale.gettext("Next Blood Moon: %dd %02dh %02dm %02ds remaining.\nStarts on day %d at %s."),
      days,
      hours,
      minutes,
      seconds,
      mod.blood_moon_day_number(start_turn),
      tostring(start_turn)
    )
    if active then message = locale.gettext("A Blood Moon is active now.") .. "\n" .. message end
    return message
  end

  ---@param params ItemUseParams
  ---@return integer
  mod.use_blood_moon_clock = function(params)
    ui.popup(mod.blood_moon_countdown_text())
    return 0
  end
end

return clock

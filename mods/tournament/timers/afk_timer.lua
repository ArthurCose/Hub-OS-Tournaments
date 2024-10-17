local Shared = require("shared")

local SECONDS = 60
local MINUTES = SECONDS * 60

local AfkTimer = {
  MAX_TIME = 3 * MINUTES
}

local TESTS = {
  Input.Pressed.Use,
  Input.Pressed.Shoot,
  Input.Pressed.Left,
  Input.Pressed.Right,
  Input.Pressed.Up,
  Input.Pressed.Down,
}

---@param player Entity
local function input_updated(player)
  for _, input in ipairs(TESTS) do
    if player:input_has(input) then
      return true
    end
  end

  return false
end

---@param field Field
function AfkTimer.init(field)
  local artifact = Shared.request_artifact(field)

  local init_component = artifact:create_component(Lifetime.Scene)
  init_component.on_update_func = function()
    init_component:eject()

    -- install afk detecting components on all players
    field:find_players(function(player)
      local afk_time = 0
      local component = player:create_component(Lifetime.Scene)

      component.on_update_func = function()
        if input_updated(player) then
          afk_time = 0
          return
        end

        afk_time = afk_time + 1

        if afk_time > AfkTimer.MAX_TIME then
          player:delete()
        end
      end

      return false
    end)
  end
end

return AfkTimer

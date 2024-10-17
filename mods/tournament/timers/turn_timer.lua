local Shared = require("shared")

local timer_root_node = Hud:create_node()

local SECONDS = 60

local TurnTimer = {
  VISIBLE_TIME = 5 * SECONDS,
  MAX_TIME = 2048 -- double slow gauge
}

---@param field Field
function TurnTimer.init(field)
  local text_node, text_shadow_node
  local time = 0

  local artifact = Shared.request_artifact(field)

  local clear_component = artifact:create_component(Lifetime.CardSelectOpen)
  clear_component.on_update_func = function()
    if text_node then
      timer_root_node:remove_node(text_node)
      timer_root_node:remove_node(text_shadow_node)
    end

    time = 0
  end


  local timer_component = artifact:create_component(Lifetime.ActiveBattle)
  timer_component.on_update_func = function()
    if time >= TurnTimer.MAX_TIME then
      TurnGauge.complete_turn()
      return
    end

    time = time + 1

    if time < TurnTimer.MAX_TIME - TurnTimer.VISIBLE_TIME then
      return
    end

    if text_node then
      timer_root_node:remove_node(text_node)
      timer_root_node:remove_node(text_shadow_node)
    end

    local remaining_time = TurnTimer.MAX_TIME - time
    local remaining_seconds = math.ceil(remaining_time / SECONDS)
    local text = tostring(remaining_seconds)

    text_node = timer_root_node:create_text_node(Shared.TEXT_STYLE, text)
    text_node:set_layer(-1)

    text_shadow_node = timer_root_node:create_text_node(Shared.TEXT_STYLE, text)
    text_shadow_node:set_color(Shared.SHADOW_COLOR)
    text_shadow_node:set_offset(1, 1)


    -- centering
    local children = text_node:children()
    local last_node = children[#children]
    local width = last_node:offset().x + last_node:width()

    timer_root_node:set_offset(120 - width // 2, 8 * 3)
  end
end

return TurnTimer

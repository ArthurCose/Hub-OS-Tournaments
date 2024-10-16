local SHADOW_COLOR = Color.new(82, 99, 115)
local TEXT_STYLE = TextStyle.new("THICK")
TEXT_STYLE.monospace = true

local timer_root_node = Hud:create_node()
timer_root_node:set_offset(240 - 16, 8 * 7)

local SECONDS = 60

---@class CardSelectTimer
local CardSelectTimer = {
  MIN_TIME = 30 * SECONDS,
  MAX_TIME = 120 * SECONDS,
  LAST_PLAYER_TIME = 20 * SECONDS,
  VISIBLE_TIME = 20 * SECONDS
}

---@param field Field
function CardSelectTimer.init(field)
  local artifact = Artifact.new()

  local open = false
  local accounted_for_last_player = false
  local elapsed_time
  local text_node, text_shadow_node

  local start_component = artifact:create_component(Lifetime.CardSelectOpen)
  start_component.on_update_func = function()
    open = true
    accounted_for_last_player = false
    elapsed_time = 0
  end

  local function account_for_last_player()
    local min_time_remaining = CardSelectTimer.MIN_TIME - elapsed_time

    elapsed_time = math.max(
      elapsed_time,
      CardSelectTimer.MAX_TIME - math.max(CardSelectTimer.LAST_PLAYER_TIME, min_time_remaining)
    )

    accounted_for_last_player = true
  end

  local timer_component = artifact:create_component(Lifetime.Scene)

  timer_component.on_update_func = function()
    if not open then
      -- wait until card select is open
      return
    end

    -- resolve the player who hasn't confirmed
    local confirm_count = 0
    local player_count = 0

    field:find_players(function(player)
      if player:deleted() or player:staged_items_confirmed() then
        confirm_count = confirm_count + 1
      end

      player_count = player_count + 1

      return false
    end)

    if text_node then
      -- remove old text nodes
      timer_root_node:remove_node(text_node)
      timer_root_node:remove_node(text_shadow_node)
      text_node = nil
    end

    if confirm_count == player_count then
      -- everyone confirmed, mark as closed and reset the timer
      open = false
      elapsed_time = nil
      return
    elseif confirm_count == player_count - 1 then
      -- one player left
      if not accounted_for_last_player then
        account_for_last_player()
      end
    end

    -- increment time
    elapsed_time = elapsed_time + 1

    if elapsed_time < CardSelectTimer.MAX_TIME - CardSelectTimer.VISIBLE_TIME then
      -- the timer doesn't need to be rendered
      return
    end

    if elapsed_time == CardSelectTimer.MAX_TIME then
      -- force confirm card select
      field:find_players(function(player)
        player:confirm_staged_items()
        return false
      end)

      return
    end

    -- create text nodes for the current frame

    local remaining_time = CardSelectTimer.MAX_TIME - elapsed_time
    local remaining_seconds = math.ceil(remaining_time / 60)
    local text = tostring(remaining_seconds)

    if #text == 1 then
      text = " " .. text
    end

    text_node = timer_root_node:create_text_node(TEXT_STYLE, text)
    text_node:set_layer(-1)

    text_shadow_node = timer_root_node:create_text_node(TEXT_STYLE, text)
    text_shadow_node:set_color(SHADOW_COLOR)
    text_shadow_node:set_offset(1, 1)
  end

  field:spawn(artifact, 0, field:height() - 1)
end

return CardSelectTimer

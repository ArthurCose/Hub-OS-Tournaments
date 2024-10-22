local PLAIN_TEXT_STYLE = TextStyle.new_monospace("THICK")
local HP_TEXT_STYLE = TextStyle.new_monospace("PLAYER_HP_ORANGE")
local BATTLE_TEXT_STYLE = TextStyle.new("BATTLE")
BATTLE_TEXT_STYLE.letter_spacing = 0
local SHADOW_COLOR = Color.new(33, 41, 41)

local SECONDS = 60

---@class HitDamageJudge
local HitDamageJudge = {
  RANDOMIZED_TIME = 72,
  TRUTH_TIME = 120,
}

---@type table<Team, number>
local tracked_damage = {
  [Team.Red] = 0,
  [Team.Blue] = 0
}

---@param text string
---@param padding number
local function left_pad(text, padding)
  return string.rep(" ", padding - #text) .. text
end

---@param text string
---@param padding number
local function right_pad(text, padding)
  return text .. string.rep(" ", padding - #text)
end

---@param node Sprite
local function centerh_text_node(node, x, y)
  local children = node:children()
  local last_node = children[#children]
  local width = last_node:offset().x + last_node:width()

  node:set_offset(x - width // 2, y)
end

local function create_text_shadow(node, text_style, text)
  local shadow_node = node:create_text_node(text_style, text)
  shadow_node:set_color(SHADOW_COLOR)
  shadow_node:set_offset(1, 1)
  shadow_node:set_layer(1)
end

-- timer display
local timer_text_node

local function set_timer_text(text)
  if timer_text_node then
    Hud:remove_node(timer_text_node)
  end

  if text == "" then
    return
  end

  timer_text_node = Hud:create_text_node(PLAIN_TEXT_STYLE, text)
  centerh_text_node(timer_text_node, 120, 4)
  create_text_shadow(timer_text_node, PLAIN_TEXT_STYLE, text)
end

-- hit damage display
local damage_node
local vs_node

local function clear_comparison()
  if damage_node then
    Hud:remove_node(damage_node)
    Hud:remove_node(vs_node)
  end
end

---@param displayed_damage table<Team, number>
---@param flip boolean
local function display_comparison(displayed_damage, flip)
  clear_comparison()

  local left_team = Team.Blue
  local right_team = Team.Red

  if flip then
    left_team = Team.Red
    right_team = Team.Blue
  end

  local left_text = tostring(displayed_damage[left_team])
  local right_text = tostring(displayed_damage[right_team])

  local damage_text = left_pad(left_text, 4) .. "    " .. right_pad(right_text, 4)

  if displayed_damage[Team.Other] then
    local middle_text = tostring(displayed_damage[Team.Other] or 0)
    damage_text = damage_text .. "\n    " .. left_pad(middle_text, 4)
  end

  damage_node = Hud:create_text_node(HP_TEXT_STYLE, damage_text)
  damage_node:set_offset(120 - (#damage_text / 2) * 8, 44)

  vs_node = Hud:create_text_node(PLAIN_TEXT_STYLE, "VS")
  centerh_text_node(vs_node, 120, 44)
  create_text_shadow(vs_node, PLAIN_TEXT_STYLE, "VS")
end

-- judge action

---@param entity Entity
local function queue_judge_action(entity)
  local executed = false
  local action = Action.new(entity)
  action:set_lockout(ActionLockout.new_sequence())

  local card_properties = CardProperties.new()
  card_properties.time_freeze = true
  card_properties.skip_time_freeze_intro = true
  action:set_card_properties(card_properties)

  local banner_node

  action.on_execute_func = function()
    executed = true

    -- hold the "TIME UP!" for one second
    local time = 0
    local time_up_step = action:create_step()
    time_up_step.on_update_func = function()
      time = time + 1

      if time >= 60 then
        set_timer_text("")
        time_up_step:complete_step()
        time = 0
      end
    end

    local flipped = false
    entity:field():find_players(function(player)
      if player:is_local() and player:team() == Team.Blue then
        flipped = true
      end

      return false
    end)

    -- display
    local CLOSE_TIME = HitDamageJudge.RANDOMIZED_TIME + HitDamageJudge.TRUTH_TIME

    local banner_width
    local banner_height
    local display_step = action:create_step()
    local randomized_damage = {}
    display_step.on_update_func = function()
      if time == 0 then
        -- initialize banner node
        banner_node = Hud:create_text_node(BATTLE_TEXT_STYLE, "<HIT_DAMAGE_JUDGE>")
        local children = banner_node:children()
        banner_height = children[1]:height()
        local last_child = children[#children]
        banner_width = last_child:offset().x + last_child:width()
      end

      time = time + 1

      -- resolve banner scale
      local y_scale = 1

      if time < 7 then
        -- time range: 1..7
        -- scale range is 0.2 -> 1.2
        y_scale = time / 5
      elseif time < 9 then
        -- time range: 7..9
        -- scale range is 1.2 -> 1
        y_scale = (14 - (time - 7)) / 12
      elseif time > CLOSE_TIME then
        if time <= CLOSE_TIME + 2 then
          -- start closing, initialy by scaling up
          -- scale range is 1 -> 1.16
          y_scale = (time - CLOSE_TIME + 12) / 12
        else
          -- scale down
          -- scale range is 1.2 -> 0
          y_scale = (CLOSE_TIME + 2 + 7 - time) / 5
          clear_comparison()
        end
      end

      if y_scale <= 0 then
        -- scaled to 0 during closing, we open with a scale larger than 0 as we increment time
        display_step:complete_step()
        return
      end

      banner_node:set_scale(1, y_scale)
      banner_node:set_offset(120 - banner_width // 2, banner_height // 2 - (banner_height * y_scale) // 2 + 17)

      if time > CLOSE_TIME then
        return
      end

      -- display hit damage
      local displayed_damage = randomized_damage

      if time < HitDamageJudge.RANDOMIZED_TIME - 2 then
        -- randomize damage
        for team, _ in pairs(tracked_damage) do
          randomized_damage[team] = math.random(9999)
        end
      elseif time > HitDamageJudge.RANDOMIZED_TIME then
        -- display true damage after a break
        displayed_damage = tracked_damage
      end

      display_comparison(displayed_damage, flipped)
    end

    local final_step = action:create_step()
    final_step.on_update_func = function()
      -- resolve winning team based on the least damage taken
      local lowest_damage = math.maxinteger

      for _, damage in pairs(tracked_damage) do
        if damage < lowest_damage then
          lowest_damage = damage
        end
      end

      -- resolve draw
      local match_count = 0

      for _, damage in pairs(tracked_damage) do
        if damage == lowest_damage then
          match_count = match_count + 1
        end
      end

      if match_count ~= 1 then
        -- set lowest_damage to -1 to delete every player
        lowest_damage = -1
      end

      -- delete players to force a win
      Field:find_players(function(player)
        if tracked_damage[player:team()] ~= lowest_damage then
          player:delete()
        end

        return false
      end)

      final_step:complete_step()
    end
  end

  action.on_action_end_func = function()
    Hud:remove_node(banner_node)
    clear_comparison()

    if not executed then
      -- retry
      queue_judge_action(entity)
      return
    end
  end

  entity:queue_action(action)
end

-- counting down to judge

---@param entity Entity
local function start_timer(entity)
  local remaining_time = 60 * 10

  local component = entity:create_component(Lifetime.ActiveBattle)
  component.on_update_func = function()
    remaining_time = remaining_time - 1

    if remaining_time == 0 then
      component:eject()
      queue_judge_action(entity)
      set_timer_text("TIME UP!")
      return
    end

    local remaining_seconds = math.ceil(remaining_time / SECONDS) + 1
    set_timer_text(tostring(remaining_seconds - 1))
  end
end

---@param field Field
function HitDamageJudge.init(field)
  local artifact = Artifact.new()
  field:spawn(artifact, 0, 0)

  local component = artifact:create_component(Lifetime.CardSelectOpen)

  component.on_update_func = function()
    if TurnGauge.current_turn() == TurnGauge.turn_limit() then
      -- count down to judgement
      start_timer(artifact)
      TurnGauge.set_enabled(false)
      component:eject()
    elseif TurnGauge.current_turn() == 1 then
      -- init hit damage tracking on all players
      field:find_players(function(player)
        local defense_rule = DefenseRule.new(DefensePriority.Last, DefenseOrder.Always)

        defense_rule.filter_func = function(props)
          if props.damage <= 0 or props.flags & Hit.Impact == 0 then
            -- we only track damage for hits marked as Hit.Impact
            return props
          end

          local damage = props.damage

          -- resolve weakness bonus
          local element = player:element()
          if Element.is_weak_to(element, props.element) or Element.is_weak_to(element, props.secondary_element) then
            damage = damage + damage
          end

          -- resolve damage removed from the tile state
          if player:current_tile():state() == TileState.Holy then
            damage = (damage + 1) // 2
          end

          local team = player:team()
          tracked_damage[team] = (tracked_damage[team] or 0) + damage

          return props
        end

        player:add_defense_rule(defense_rule)

        return false
      end)
    end
  end
end

return HitDamageJudge

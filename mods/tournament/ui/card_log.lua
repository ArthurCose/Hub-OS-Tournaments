local LINE_HEIGHT = 8
local CARD_ICON_WIDTH = 14
local TEXT_STYLE = TextStyle.new_monospace("THICK")
local BATTLE_TEXT_STYLE = TextStyle.new("BATTLE")
BATTLE_TEXT_STYLE.letter_spacing = 0
local SHADOW_COLOR = Color.new(33, 41, 41)

local animator = Animation.new("card_log.animation")
animator:set_state("DEFAULT")

-- nodes
local root_node = Hud:create_node()
root_node:set_visible(false)
root_node:set_layer(-1)

local background_node = root_node:create_node()
background_node:set_texture(Resources.load_texture("card_log.png"))
background_node:set_color(Color.new(0, 0, 0, 192))
background_node:set_layer(1)
animator:apply(background_node)
root_node:set_offset((240 - background_node:width()) // 2, (160 - background_node:height()) // 2)

local log_nodes = {}

-- log positions
local LOG_START = animator:get_point("LOG_START")
local LOG_END = animator:get_point("LOG_END")
local LOG_WIDTH = LOG_END.x - LOG_START.x
LOG_END.y = LOG_END.y - LINE_HEIGHT

-- main export
local CardLog = {}

local function shift_and_resolve_bottom()
  local log_bottom = LOG_END.y

  for _, node in ipairs(log_nodes) do
    local offset = node:offset()
    log_bottom = offset.y

    offset.y = offset.y - LINE_HEIGHT

    node:set_offset(offset.x, offset.y)

    if offset.y < LOG_START.y then
      node:set_visible(false)
    end
  end

  return log_bottom
end

---@param text_style TextStyle
---@param shadow_color Color?
---@param message string
function CardLog.log_message(text_style, shadow_color, message)
  -- shift everything up and resolve the bottom of the log
  local log_bottom = shift_and_resolve_bottom()

  local metrics = TextStyle.measure(text_style, message)
  local width = metrics.width // 2

  local text_node = root_node:create_text_node(text_style, message)
  text_node:set_offset(LOG_START.x + (LOG_WIDTH - width) // 2, log_bottom)

  if shadow_color then
    local shadow_node = text_node:create_text_node(text_style, message)
    shadow_node:set_color(shadow_color)
    shadow_node:set_offset(1, 1)
    shadow_node:set_layer(1)
  end

  text_node:set_scale(0.5, 0.5)

  log_nodes[#log_nodes + 1] = text_node

  return text_node
end

---@param entity Entity
---@param card_props CardProperties
function CardLog.log_card(entity, card_props)
  if card_props.package_id == "" then
    return
  end

  -- shift everything up and resolve the bottom of the log
  local log_bottom = shift_and_resolve_bottom()

  -- create a new node
  local log_node = root_node:create_node()
  log_nodes[#log_nodes + 1] = log_node

  local icon_texture = CardProperties.icon_texture(card_props)
  log_node:create_node():set_texture(icon_texture)

  local metrics = TextStyle.measure(TEXT_STYLE, string.rep("A", math.max(8, #card_props.short_name)))
  local text_node = log_node:create_text_node(TEXT_STYLE, card_props.short_name)
  text_node:set_offset(CARD_ICON_WIDTH + 2, (CARD_ICON_WIDTH - metrics.height) // 2)

  local shadow_node = text_node:create_text_node(TEXT_STYLE, card_props.short_name)
  shadow_node:set_color(SHADOW_COLOR)
  shadow_node:set_offset(1, 1)
  shadow_node:set_layer(1)

  log_node:set_scale(0.5, 0.5)

  -- align
  local width = (CARD_ICON_WIDTH + 2 + metrics.width) // 2
  local team = entity:team()

  if team == Team.Red then
    -- left align
    log_node:set_offset(LOG_START.x, log_bottom)
  elseif team == Team.Blue then
    -- right align
    log_node:set_offset(LOG_START.x + LOG_WIDTH - width, log_bottom)
  else
    -- center
    log_node:set_offset(LOG_START.x + (LOG_WIDTH - width) // 2, log_bottom)
  end
end

function CardLog.clear()
  for i = #log_nodes, 1, -1 do
    root_node:remove_node(log_nodes[i])
    log_nodes[i] = nil
  end
end

---@param amount number
function CardLog.scroll(amount)
  -- resolve scroll based on the last node's position
  local last_node = log_nodes[#log_nodes]

  if not last_node then
    return
  end

  local scroll = (last_node:offset().y - LOG_END.y) / LINE_HEIGHT

  -- limit scrolling down
  if scroll + amount < 0 then
    amount = amount - (scroll + amount)
  end

  -- shift everything
  local shift = amount * LINE_HEIGHT

  for _, node in ipairs(log_nodes) do
    local offset = node:offset()
    offset.y = offset.y + shift

    node:set_offset(offset.x, offset.y)

    -- hide nodes that are out of bounds
    node:set_visible(offset.y >= LOG_START.y and offset.y <= LOG_END.y)
  end
end

function CardLog.visible()
  return root_node:visible()
end

function CardLog.set_visible(visible)
  root_node:set_visible(visible)
end

---@param field Field
function CardLog.init(field)
  local artifact = Artifact.new()

  artifact.on_update_func = function()
    -- find and track players
    field:find_players(function(player)
      local aux_prop = AuxProp.new()
          :intercept_action(function(action)
            local card_props = action:copy_card_properties()
            CardLog.log_card(player, card_props)
            return action
          end)

      player:add_aux_prop(aux_prop)

      return false
    end)

    -- clear update function
    artifact.on_update_func = nil
  end

  local turn_start_component = artifact:create_component(Lifetime.CardSelectComplete)
  turn_start_component.on_update_func = function()
    CardLog.clear()

    local node = CardLog.log_message(BATTLE_TEXT_STYLE, nil, "<TURN_" .. TurnGauge.current_turn() .. "_START>")
    local offset = node:offset()

    node:set_offset(offset.x, offset.y - 1)
  end

  field:spawn(artifact, 0, 0)
end

return CardLog

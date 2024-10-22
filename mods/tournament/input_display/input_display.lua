---@class InputDisplay
local InputDisplay = {}

local TEXTURE = Resources.load_texture("inputs.png")
local animation = Animation.new("inputs.animation")
local is_visible = true

local ICON_LEN = 12

---@param player Entity
function InputDisplay.resolve_direction_state(player)
  local up = player:input_has(Input.Held.Up)
  local down = player:input_has(Input.Held.Down)
  local left = player:input_has(Input.Held.Left)
  local right = player:input_has(Input.Held.Right)

  local vertical_state = nil
  local horizontal_state = nil

  if up and not down then
    vertical_state = "UP"
  elseif down and not up then
    vertical_state = "DOWN"
  end

  if left and not right then
    horizontal_state = "LEFT"
  elseif right and not left then
    horizontal_state = "RIGHT"
  end

  if not horizontal_state then
    return vertical_state
  elseif not vertical_state then
    return horizontal_state
  else
    return vertical_state .. "_" .. horizontal_state
  end
end

---@param parent_node Sprite
---@param state string
local function create_node_with_state(parent_node, state)
  local node = parent_node:create_node()
  node:set_texture(TEXTURE)
  animation:set_state(state)
  animation:apply(node)
  return node
end

---@param player Entity
---@param inputs Input[]
local function test_inputs(player, inputs)
  for _, input in ipairs(inputs) do
    if player:input_has(input) then
      return true
    end
  end

  return false
end

---@param player Entity
function InputDisplay.track(player)
  local component = player:create_component(Lifetime.Scene)

  local root_node = player:create_node()
  root_node:set_never_flip(true)

  local direction_node = create_node_with_state(root_node, "DOWN")
  local a_node = create_node_with_state(root_node, "A")
  local b_node = create_node_with_state(root_node, "B")
  local x_node = create_node_with_state(root_node, "X")
  local y_node = create_node_with_state(root_node, "Y")
  local shoulders_node = create_node_with_state(root_node, "SHOULDERS")

  local nodes_and_tests = {
    { a_node,         { Input.Held.Use } },
    { b_node,         { Input.Held.Shoot } },
    { x_node,         { Input.Held.Special } },
    { y_node,         { Input.Held.FaceLeft, Input.Held.FaceRight } },
    { shoulders_node, { Input.Held.LeftShoulder, Input.Held.RightShoulder } },
  }

  component.on_update_func = function()
    if not is_visible or not player:staged_items_confirmed() then
      root_node:set_visible(false)
      return
    end

    root_node:set_visible(true)

    local offset = 0

    -- resolve direction
    local direction_state = InputDisplay.resolve_direction_state(player)

    if direction_state then
      direction_node:set_visible(true)
      animation:set_state(direction_state)
      animation:apply(direction_node)
      offset = offset + ICON_LEN
    else
      direction_node:set_visible(false)
    end

    -- resolve buttons
    for _, node_and_tests in ipairs(nodes_and_tests) do
      local node = node_and_tests[1]
      if test_inputs(player, node_and_tests[2]) then
        node:set_visible(true)
        node:set_offset(offset, 0)
        offset = offset + ICON_LEN
      else
        node:set_visible(false)
      end
    end

    -- resolve root offset
    local x_offset = -math.floor(offset / 2)

    if player:facing() == Direction.Left then
      x_offset = -x_offset
    end

    root_node:set_offset(x_offset, -ICON_LEN - player:height())
  end
end

function InputDisplay.visible()
  return is_visible
end

function InputDisplay.set_visible(visible)
  is_visible = visible
end

return InputDisplay

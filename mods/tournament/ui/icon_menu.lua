local cursor_template_node = Hud:create_node()
cursor_template_node:set_texture(Resources.load_texture("ui.png"))
cursor_template_node:set_visible(false)

local animation = Animation.new("ui.animation")
animation:set_state("HIGHLIGHT")
animation:apply(cursor_template_node)

local cursor_origin = cursor_template_node:origin()

local CELL_W = 18
local CELL_H = 18

---@class IconMenu
---@field private ui_sprite Sprite
---@field private cursor_node Sprite
---@field private animation_path string
---@field private option_nodes Sprite[]
---@field private spectator_data table<number, number>
---@field on_confirm fun(spectator_index: number, index: number)
---@field on_cancel fun(spectator_index: number)
local IconMenu = {}
IconMenu.__index = IconMenu

---@param option_states string[]
---@return IconMenu
function IconMenu.new(texture, animation_path, option_states)
  -- create base ui node
  local ui_sprite = Hud:create_node()
  ui_sprite:set_offset(
    math.floor(CELL_W / 2) + 2,
    160 - CELL_H + cursor_origin.y + 1
  )

  -- create cursor node
  local cursor_node = ui_sprite:create_node()
  cursor_node:copy_from(cursor_template_node)
  cursor_node:set_visible(true)

  -- create option nodes
  local option_nodes = {}

  animation:load(animation_path)

  for col = 1, #option_states do
    local emote_name = option_states[col]

    local node = ui_sprite:create_node()
    node:set_texture(texture)
    animation:set_state(emote_name)
    animation:apply(node)

    node:set_offset((col - 1) * CELL_W, 0)
    option_nodes[#option_nodes + 1] = node
  end

  local submenu = {
    ui_sprite = ui_sprite,
    cursor_node = cursor_node,
    animation_path = animation_path,
    option_nodes = option_nodes,
    spectator_data = {}
  }
  setmetatable(submenu, IconMenu)
  return submenu
end

---@param index number
---@param state string
function IconMenu:set_icon_state(index, state)
  animation:load(self.animation_path)
  animation:set_state(state)
  animation:apply(self.option_nodes[index])
end

---@param visible boolean
function IconMenu:set_visible(visible)
  self.ui_sprite:set_visible(visible)
end

---@param spectator_index number
function IconMenu:handle_input(spectator_index)
  -- handle moving the cursor
  local pulsed_left = Resources.input_has(spectator_index, Input.Pulsed.Left)
  local pulsed_right = Resources.input_has(spectator_index, Input.Pulsed.Right)

  local index = self.spectator_data[spectator_index] or 1

  if pulsed_left and not pulsed_right then
    index = index - 1

    if index <= 0 then
      index = #self.option_nodes
    end
  end

  if pulsed_right and not pulsed_left then
    index = index % #self.option_nodes + 1
  end

  if Resources.is_local(spectator_index) then
    self.cursor_node:set_offset((index - 1) * CELL_W, 0)
  end

  self.spectator_data[spectator_index] = index

  if self.on_confirm and Resources.input_has(spectator_index, Input.Pressed.Confirm) then
    self.on_confirm(spectator_index, index)
  end

  if self.on_cancel and Resources.input_has(spectator_index, Input.Pulsed.Cancel) then
    self.on_cancel(spectator_index)
  end
end

return IconMenu

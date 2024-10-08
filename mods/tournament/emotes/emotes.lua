local CELL_W = 18
local CELL_H = 18

local ALPHA_DECAY = 2

local EMOTE_GRID = {
  {
    "BIG SMILE",
    "EXPLODING HEAD MIND BLOWN",
    "SUNGLASSES",
    "CRYING SUNGLASSES",
    "PLEADING",
    "COB",
    "EXCLAMATION MARK!",
    "QUESTION MARK?",
    "LOVE HEART",
    "EVIL GRIN SMILING IMP",
  }
}

---@type table<string, Sprite>
local emote_template_nodes = {}

---@class EmoteNode: Sprite
---@field _color Color

---@type EmoteNode[]
local emote_nodes = {}

local COLS = #EMOTE_GRID[1]
local ROWS = #EMOTE_GRID

local ui_sprite = Hud:create_node()
ui_sprite:set_visible(false)

local view_artifact = Artifact.new()
local view_sprite = view_artifact:sprite()
Field:spawn(view_artifact, 0, 0)

local EMOTE_TEXTURE = Resources.load_texture("emotes.png")
local animator = view_artifact:animation()
animator:load("emotes.animation")

-- build view grid
view_sprite:set_texture(EMOTE_TEXTURE)

for row = 1, ROWS do
  local emote_row = EMOTE_GRID[row]

  for col = 1, COLS do
    local emote_name = emote_row[col]

    local node = ui_sprite:create_node()
    node:set_texture(EMOTE_TEXTURE)
    animator:set_state(emote_name)
    animator:apply(node)

    node:set_offset((col - 1) * CELL_W, (row - 1) * CELL_H)
    emote_template_nodes[emote_name] = node
  end
end

local cursor_node = ui_sprite:create_node()
cursor_node:set_layer(-1)
cursor_node:set_texture("ui.png")
animator:load("ui.animation")
animator:set_state("HIGHLIGHT")
animator:apply(cursor_node)

local cursor_origin = cursor_node:origin()
ui_sprite:set_offset(
  0,
  -- 120 - math.floor(COLS * CELL_W / 2) + cursor_origin.x,
  160 - ROWS * CELL_H + cursor_origin.y
)

-- handle emote fading and despawning

local view_component = view_artifact:create_component(Lifetime.Scene)

view_component.on_update_func = function()
  for i = #emote_nodes, 1, -1 do
    local node = emote_nodes[i]
    node._color.a = node._color.a - ALPHA_DECAY
    node:set_color(node._color)

    if node._color.a <= 0 then
      view_sprite:remove_node(node)

      -- swap remove
      emote_nodes[i] = emote_nodes[#emote_nodes]
      emote_nodes[#emote_nodes] = nil
    end
  end
end

local function spawn_emote(name)
  local template_node = emote_template_nodes[name]

  local node = view_sprite:create_node() --[[@as EmoteNode]]
  node._color = node:color()
  node:copy_from(template_node)
  node:set_offset(
    math.random(Tile:width(), (Field:width() - 2) * Tile:width()),
    math.random(-Tile:height() * 1.5, Tile:height() / 2 - 4)
  )

  emote_nodes[#emote_nodes + 1] = node
end

---@param spectator Entity
return function(spectator)
  local ui_open = false
  local cursor_x = 0
  local cursor_y = 0

  local component = spectator:create_component(Lifetime.Scene)

  component.on_update_func = function()
    if spectator:input_has(Input.Pressed.Cancel) then
      ui_open = false
    elseif spectator:input_has(Input.Pressed.Special) then
      ui_open = not ui_open
    end

    if not ui_open then
      if spectator:is_local() then
        ui_sprite:set_visible(ui_open)
      end

      return
    end

    -- handle moving the cursor
    local pulsed_left = spectator:input_has(Input.Pulsed.Left)
    local pulsed_right = spectator:input_has(Input.Pulsed.Right)
    local pulsed_up = spectator:input_has(Input.Pulsed.Up)
    local pulsed_down = spectator:input_has(Input.Pulsed.Down)

    if pulsed_left and not pulsed_right then
      cursor_x = cursor_x - 1

      if cursor_x < 0 then
        cursor_x = COLS - 1
      end
    end

    if pulsed_right and not pulsed_left then
      cursor_x = (cursor_x + 1) % COLS
    end

    if pulsed_up and not pulsed_down then
      cursor_y = cursor_y - 1

      if cursor_y < 0 then
        cursor_y = ROWS - 1
      end
    end

    if pulsed_down and not pulsed_up then
      cursor_y = (cursor_y + 1) % ROWS
    end

    if spectator:input_has(Input.Pulsed.Confirm) then
      spawn_emote(EMOTE_GRID[cursor_y + 1][cursor_x + 1])
      ui_open = false
    end

    if spectator:is_local() then
      ui_sprite:set_visible(ui_open)
      cursor_node:set_offset(cursor_x * CELL_W, cursor_y * CELL_H)
    end
  end
end

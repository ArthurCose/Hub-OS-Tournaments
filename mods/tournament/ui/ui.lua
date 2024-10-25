local InputDisplay = require("../input_display/input_display")
local IconMenu = require("icon_menu")
local CardLog = require("card_log")
local spawn_emote = require("emotes")

-- define player specific data
---@alias SpectatorMenu { handle_input: fun(self, entity: Entity) }
---@type table<EntityId, SpectatorMenu>
local player_data = {}

-- base menu
local base_menu = IconMenu.new(
  Resources.load_texture("ui.png"),
  "ui.animation",
  {
    "EMOTES",
    "CARD_LOG",
    "INPUT_DISPLAY",
  }
)

-- emotes menu
local emotes = {
  "BIG SMILE",
  "COB",
  "EVIL GRIN SMILING IMP",
  "EXPLODING HEAD MIND BLOWN",
  "SUNGLASSES",
  "CRYING SUNGLASSES",
  "PLEADING",
  "EXCLAMATION MARK!",
  "QUESTION MARK?",
  "LOVE HEART",
}

local emotes_menu = IconMenu.new(
  Resources.load_texture("emotes.png"),
  "emotes.animation",
  emotes
)

-- emotes menu event handling

local function toggle_emotes_menu(player)
  local visible = player_data[player:id()] ~= emotes_menu

  if player:is_local() then
    emotes_menu:set_visible(visible)
    base_menu:set_visible(not visible)
  end

  if visible then
    player_data[player:id()] = emotes_menu
  else
    player_data[player:id()] = base_menu
  end
end

emotes_menu.on_confirm = function(player, index)
  toggle_emotes_menu(player)
  spawn_emote(emotes[index])
end

emotes_menu.on_cancel = toggle_emotes_menu

-- CardLog menu and input handling
local card_log_menu = {}

---@param player Entity
function card_log_menu:handle_input(player)
  if player:input_has(Input.Pressed.Cancel) then
    -- close menu
    player_data[player:id()] = base_menu

    if player:is_local() then
      CardLog.set_visible(false)
    end
  end

  if not player:is_local() then
    return
  end

  -- resolve scroll amount
  local amount = 0

  if player:input_has(Input.Pulsed.Up) then
    amount = amount + 1
  end

  if player:input_has(Input.Pulsed.Down) then
    amount = amount - 1
  end

  if amount ~= 0 then
    CardLog.scroll(amount)
  end
end

-- base menu event handling

base_menu.on_confirm = function(player, index)
  if index == 1 then
    toggle_emotes_menu(player)
  elseif index == 2 then
    if player:is_local() then
      CardLog.set_visible(true)
    end

    player_data[player:id()] = card_log_menu
  elseif player:is_local() then
    local visible = not InputDisplay.visible()
    InputDisplay.set_visible(visible)

    if visible then
      base_menu:set_icon_state(3, "INPUT_DISPLAY")
    else
      base_menu:set_icon_state(3, "INPUT_DISPLAY_OFF")
    end
  end
end

-- setting up the ui for spectators

base_menu:set_visible(false)
emotes_menu:set_visible(false)

---@param player Entity
return function(player)
  player_data[player:id()] = base_menu

  if player:is_local() then
    base_menu:set_visible(true)
  end

  local component = player:create_component(Lifetime.Scene)
  component.on_update_func = function()
    player_data[player:id()]:handle_input(player)
  end
end

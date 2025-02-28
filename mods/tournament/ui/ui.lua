local InputDisplay = require("../input_display/input_display")
local IconMenu = require("icon_menu")
local CardLog = require("card_log")
local spawn_emote = require("emotes")

-- define spectator specific data
---@alias SpectatorMenu { handle_input: fun(self, spectator_index: number) }
---@type table<number, SpectatorMenu>
local spectator_menu_map = {}

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

local function toggle_emotes_menu(spectator_index)
  local visible = spectator_menu_map[spectator_index] ~= emotes_menu

  if Resources.is_local(spectator_index) then
    emotes_menu:set_visible(visible)
    base_menu:set_visible(not visible)
  end

  if visible then
    spectator_menu_map[spectator_index] = emotes_menu
  else
    spectator_menu_map[spectator_index] = base_menu
  end
end

emotes_menu.on_confirm = function(spectator_index, index)
  toggle_emotes_menu(spectator_index)
  spawn_emote(emotes[index])
end

emotes_menu.on_cancel = toggle_emotes_menu

-- CardLog menu and input handling
local card_log_menu = {}

---@param spectator_index number
function card_log_menu:handle_input(spectator_index)
  if Resources.input_has(spectator_index, Input.Pressed.Cancel) then
    -- close menu
    spectator_menu_map[spectator_index] = base_menu

    if Resources.is_local(spectator_index) then
      CardLog.set_visible(false)
    end
  end

  if not Resources.is_local(spectator_index) then
    return
  end

  -- resolve scroll amount
  local amount = 0

  if Resources.input_has(spectator_index, Input.Pulsed.Up) then
    amount = amount + 1
  end

  if Resources.input_has(spectator_index, Input.Pulsed.Down) then
    amount = amount - 1
  end

  if amount ~= 0 then
    CardLog.scroll(amount)
  end
end

-- base menu event handling

base_menu.on_confirm = function(spectator_index, index)
  if index == 1 then
    toggle_emotes_menu(spectator_index)
  elseif index == 2 then
    if Resources.is_local(spectator_index) then
      CardLog.set_visible(true)
    end

    spectator_menu_map[spectator_index] = card_log_menu
  elseif Resources.is_local(spectator_index) then
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

---iffy causes error?
local function init()
  local entity = Artifact.new()

  local component = entity:create_component(Lifetime.Scene)
  component.on_update_func = function()
    for spectator_index, menu in pairs(spectator_menu_map) do
      menu:handle_input(spectator_index)
    end
  end

  Field:spawn(entity, 0, 0)
end

init()

---@param spectator_index number
return function(spectator_index)
  spectator_menu_map[spectator_index] = base_menu

  if Resources.is_local(spectator_index) then
    base_menu:set_visible(true)
  end
end

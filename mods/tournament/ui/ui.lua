local InputDisplay = require("../input_display/input_display")
local IconMenu = require("icon_menu")
local CardLog = require("card_log")
local spawn_emote = require("emotes")
local SpectatorMenuSystem = require("spectator_menu_system")

-- base menu
local base_menu = SpectatorMenuSystem.create_menu()
local base_menu_inner = IconMenu.new(
  Resources.load_texture("ui.png"),
  "ui.animation",
  {
    "EMOTES",
    "CARD_LOG",
    "INPUT_DISPLAY",
  }
)

base_menu:on_open(function(player_index)
  if Resources.is_local(player_index) then
    base_menu_inner:set_visible(true)
  end
end)

base_menu:on_focus(function(player_index)
  if Resources.is_local(player_index) then
    base_menu_inner:set_visible(true)
  end
end)

base_menu:on_input(function(player_index)
  base_menu_inner:handle_input(player_index)
end)

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

local emotes_menu = SpectatorMenuSystem.create_menu()
local emotes_menu_inner = IconMenu.new(
  Resources.load_texture("emotes.png"),
  "emotes.animation",
  emotes
)

emotes_menu:on_open(function(player_index)
  if Resources.is_local(player_index) then
    emotes_menu_inner:set_visible(true)
  end
end)

emotes_menu:on_close(function(player_index)
  if Resources.is_local(player_index) then
    emotes_menu_inner:set_visible(false)
  end
end)

emotes_menu:on_input(function(player_index)
  emotes_menu_inner:handle_input(player_index)
end)

emotes_menu_inner.on_confirm = function(player_index, index)
  spawn_emote(emotes[index])
end

emotes_menu_inner.on_cancel = function(player_index)
  emotes_menu:close(player_index)
end

-- CardLog menu and input handling
local card_log_menu = SpectatorMenuSystem.create_menu()

card_log_menu:on_open(function(player_index)
  if Resources.is_local(player_index) then
    CardLog.set_visible(true)
  end
end)

card_log_menu:on_close(function(player_index)
  if Resources.is_local(player_index) then
    CardLog.set_visible(false)
  end
end)

card_log_menu:on_input(function(player_index)
  if Resources.input_has(player_index, Input.Pressed.Cancel) then
    -- close menu
    card_log_menu:close(player_index)
  end

  if not Resources.is_local(player_index) then
    return
  end

  -- resolve scroll amount
  local amount = 0

  if Resources.input_has(player_index, Input.Pulsed.Up) then
    amount = amount + 1
  end

  if Resources.input_has(player_index, Input.Pulsed.Down) then
    amount = amount - 1
  end

  if amount ~= 0 then
    CardLog.scroll(amount)
  end
end)

-- base menu event handling

base_menu_inner.on_confirm = function(player_index, index)
  if index == 1 then
    emotes_menu:open(player_index)

    if Resources.is_local(player_index) then
      base_menu_inner:set_visible(false)
    end
  elseif index == 2 then
    card_log_menu:open(player_index)
  elseif Resources.is_local(player_index) then
    local visible = not InputDisplay.visible()
    InputDisplay.set_visible(visible)

    if visible then
      base_menu_inner:set_icon_state(3, "INPUT_DISPLAY")
    else
      base_menu_inner:set_icon_state(3, "INPUT_DISPLAY_OFF")
    end
  end
end

-- setting up the ui for spectators

base_menu_inner:set_visible(false)
emotes_menu_inner:set_visible(false)

local SpectatorFunLib = {}

---@param encounter Encounter
function SpectatorFunLib.init(encounter)
  CardLog.init()

  SpectatorMenuSystem.on_spectate(encounter, function(player_index)
    base_menu:open(player_index)
  end)

  -- bind and hide input display on players
  local entity = Artifact.new()

  entity.on_spawn_func = function()
    Field.find_players(function(player)
      InputDisplay.track(player)

      if player:is_local() then
        InputDisplay.set_visible(false)
      end

      return false
    end)

    entity:delete()
  end

  Field.spawn(entity, 0, 0)
end

return SpectatorFunLib

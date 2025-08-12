---@type table<number, SpectatorMenu[]>
local open_menus_by_spectator = {}

---@class SpectatorMenu
---@field package _input_listeners fun(player_index: number)[]
---@field private _open_listeners fun(player_index: number)[]
---@field private _close_listeners fun(player_index: number)[]
---@field private _focus_listeners fun(player_index: number)[]
---@field private _blur_listeners fun(player_index: number)[]
local SpectatorMenu = {}
SpectatorMenu.__index = SpectatorMenu

---The callback will be called to handle input when this is the top menu
---@param callback fun(player_index: number)
function SpectatorMenu:on_input(callback)
  self._input_listeners[#self._input_listeners + 1] = callback
end

---The callback will be called both when :open() is called
---@param callback fun(player_index: number)
function SpectatorMenu:on_open(callback)
  self._open_listeners[#self._open_listeners + 1] = callback
end

---The callback will be called both when :close() is called
---@param callback fun(player_index: number)
function SpectatorMenu:on_close(callback)
  self._close_listeners[#self._close_listeners + 1] = callback
end

---The callback will be called both when :open() is called and when a menu opened just after this menu is closed
---@param callback fun(player_index: number)
function SpectatorMenu:on_focus(callback)
  self._focus_listeners[#self._focus_listeners + 1] = callback
end

---The callback will be called both when :close() is called and when a menu opened just after this menu is closed
---@param callback fun(player_index: number)
function SpectatorMenu:on_blur(callback)
  self._blur_listeners[#self._blur_listeners + 1] = callback
end

---Activates open listeners, then focus listeners
---@param player_index number
function SpectatorMenu:open(player_index)
  local open_menus = open_menus_by_spectator[player_index]

  if not open_menus then
    open_menus = {}
    open_menus_by_spectator[player_index] = open_menus
  end

  open_menus[#open_menus + 1] = self

  for _, listener in ipairs(self._open_listeners) do
    listener(player_index)
  end

  for _, listener in ipairs(self._focus_listeners) do
    listener(player_index)
  end
end

---Activates blur listeners, then close listeners, then focus listeners for the previous menu if this is the top menu
---@param player_index number
function SpectatorMenu:close(player_index)
  local open_menus = open_menus_by_spectator[player_index]

  if not open_menus then
    return
  end

  for i = #open_menus, 1, -1 do
    if open_menus[i] == self then
      local was_top_menu = self:has_focus(player_index)
      table.remove(open_menus, i)

      for _, listener in ipairs(self._blur_listeners) do
        listener(player_index)
      end

      for _, listener in ipairs(self._close_listeners) do
        listener(player_index)
      end

      local new_top_menu = open_menus[#open_menus]

      if was_top_menu and new_top_menu then
        for _, listener in ipairs(new_top_menu._focus_listeners) do
          listener(player_index)
        end
      end

      break
    end
  end
end

---@param player_index number
function SpectatorMenu:has_focus(player_index)
  local open_menus = open_menus_by_spectator[player_index]
  return open_menus[#open_menus] == self
end

---@class SpectatorMenuSystem
local SpectatorMenuSystem = {}

---@return SpectatorMenu
function SpectatorMenuSystem.create_menu()
  local menu = {
    _input_listeners = {},
    _open_listeners = {},
    _close_listeners = {},
    _focus_listeners = {},
    _blur_listeners = {},
  }
  setmetatable(menu, SpectatorMenu)
  return menu
end

local _spectate_listeners = {}
local player_count

---@param encounter Encounter
---@param callback fun(player_index: number)
function SpectatorMenuSystem.on_spectate(encounter, callback)
  player_count = encounter:player_count()
  _spectate_listeners[#_spectate_listeners + 1] = callback
end

local function init()
  local entity = Artifact.new()

  -- add component to drive input
  local input_component = entity:create_component(Lifetime.Scene)
  input_component.on_update_func = function()
    for player_index, open_menus in pairs(open_menus_by_spectator) do
      local top_menu = open_menus[#open_menus]

      if top_menu then
        for _, listener in ipairs(top_menu._input_listeners) do
          listener(player_index)
        end
      end
    end
  end

  -- detect spectators
  local detection_component = entity:create_component(Lifetime.Scene)
  detection_component.on_update_func = function()
    local found = {}

    Field.find_players(function(player)
      local player_index = player:player_index()
      found[player_index] = true

      player:on_delete(function()
        for _, callback in ipairs(_spectate_listeners) do
          callback(player_index)
        end
      end)

      return false
    end)

    for i = 0, player_count - 1 do
      if not found[i] then
        for _, callback in ipairs(_spectate_listeners) do
          callback(i)
        end
      end
    end

    -- we only needed to check on the first frame
    detection_component:eject()
  end

  Field.spawn(entity, 0, 0)
end

init()

return SpectatorMenuSystem

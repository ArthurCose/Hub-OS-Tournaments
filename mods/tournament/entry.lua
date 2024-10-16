local init_emotes_for = require("emotes/emotes")
local handle_team_disparity = require("handle_team_disparity")
local CardSelectTimer = require("card_select_timer")
local InputDisplay = require("input_display/input_display")

local player_count = 0
local cards_ready = 0
---@type Entity[]
local spectators = {}

---@param player Entity
local function init_player(player)
  local component = player:create_component(Lifetime.CardSelectClose)
  component.on_update_func = function()
    cards_ready = cards_ready + 1

    if cards_ready ~= player_count then
      return
    end

    -- force close spectator cards select
    for _, spectator in ipairs(spectators) do
      spectator:confirm_staged_items()
    end
  end

  player:on_delete(function()
    -- remove spectators from the battle to allow it to end
    for _, spectator in ipairs(spectators) do
      spectator:erase()
    end
  end)

  -- bind and hide input display
  InputDisplay.track(player)

  if player:is_local() then
    InputDisplay.set_visible(false)
  end
end

---@param spectator Entity
local function init_spectator(spectator)
  spectators[#spectators + 1] = spectator

  spectator:set_team(Team.Other)

  -- remove from field
  spectator:current_tile():remove_entity(spectator)

  -- strip augments
  for _, augment in ipairs(spectator:augments()) do
    spectator:boost_augment(augment:id(), -augment:level())
  end

  -- clear deck
  for i = #spectator:deck_cards(), 1, -1 do
    spectator:remove_deck_card(i)
  end

  -- card select component
  local card_select_component = spectator:create_component(Lifetime.CardSelectOpen)

  card_select_component.on_update_func = function()
    spectator:confirm_staged_items()
  end

  init_emotes_for(spectator)
end

---@param encounter Encounter
---@param data { red_count: number, blue_count: number }
function encounter_init(encounter, data)
  -- init card select timer
  CardSelectTimer.init(encounter:field())

  -- background and music
  encounter:set_background("battle-bg.png", "battle-bg.animation")

  local music = {
    "music/12. Battle Field.ogg",
    "music/12. Powerful Enemy.ogg",
    "music/19. Surge of Power!.ogg"
  }

  encounter:set_music(music[math.random(#music)])

  -- spawn players
  player_count = data.red_count + data.blue_count

  local spawn_pattern = {
    { 2, 2 }, -- center
    { 1, 3 }, -- bottom left
    { 1, 1 }, -- top left
    { 3, 3 }, -- bottom right
    { 3, 1 }, -- top right
    { 1, 2 }, -- back
    { 3, 2 }, -- front
    { 2, 1 }, -- top
    { 2, 3 }, -- bottom
  }

  for i = 0, player_count - 1 do
    local spawn_index = i
    local is_blue = i >= data.red_count

    if is_blue then
      spawn_index = spawn_index - data.red_count
    end

    spawn_index = spawn_index % #spawn_pattern + 1

    local position = spawn_pattern[spawn_index]

    if is_blue then
      -- blue (mirror)
      encounter:spawn_player(i, 7 - position[1], position[2])
    else
      -- red
      encounter:spawn_player(i, position[1], position[2])
    end
  end

  -- spawn spectator players at 0, 0 to mark as spectators
  for i = player_count, encounter:player_count() - 1 do
    encounter:spawn_player(i, 0, 0)
  end

  -- hack to detect the players we moved to 0, 0 and convert them to spectators
  local entity = Artifact.new()
  local field = encounter:field()

  entity.on_spawn_func = function()
    field:find_players(function(player)
      local tile = player:current_tile()

      if tile:x() ~= 0 then
        init_player(player)
        return false
      end

      init_spectator(player)
      return false
    end)

    handle_team_disparity(field)

    entity:erase()
  end

  field:spawn(entity, 0, 0)
end

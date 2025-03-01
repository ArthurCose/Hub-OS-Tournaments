local init_ui_for = require("ui/ui")
local CardLog = require("ui/card_log")
local handle_team_disparity = require("handle_team_disparity")
local CardSelectTimer = require("timers/card_select_timer")
local TurnTimer = require("timers/turn_timer")
local AfkTimer = require("timers/afk_timer")
local InputDisplay = require("input_display/input_display")
local HitDamageJudge = require("hit_damage_judge")

CardSelectTimer.MAX_TIME = 60 * 60

local player_count = 0

---@param index number
local function init_spectator(index)
  init_ui_for(index)
end

---@param player Entity
local function init_player(player)
  -- bind and hide input display
  InputDisplay.track(player)

  if player:is_local() then
    InputDisplay.set_visible(false)
  end

  player:on_delete(function(player)
    init_spectator(player:player_index())
  end)
end

---@param encounter Encounter
---@param data { red_count: number, blue_count: number, spectator_count: number }
function encounter_init(encounter, data)
  -- init timers
  local field = encounter:field()
  CardSelectTimer.init(field)
  TurnTimer.init(field)
  AfkTimer.init(field)
  HitDamageJudge.init(field)
  CardLog.init(field)

  encounter:set_turn_limit(15)
  encounter:set_spectate_on_delete(true)

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

  for i = player_count, player_count + data.spectator_count do
    encounter:mark_spectator(i)
    init_spectator(i)
  end

  -- entity to init players on the first frame they're made available
  local entity = Artifact.new()

  entity.on_spawn_func = function()
    field:find_players(function(player)
      init_player(player)
      return false
    end)

    handle_team_disparity(field)

    entity:erase()
  end

  field:spawn(entity, 0, 0)
end

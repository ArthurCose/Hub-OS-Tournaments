local HitDamageJudge = require("BattleNetwork6.Libraries.HitDamageJudge")
local Timers = require("dev.konstinople.library.timers")

local SpectatorFun = require("ui/ui")
local handle_team_disparity = require("handle_team_disparity")

Timers.CardSelectTimer.MAX_TIME = 60 * 60

local player_count = 0

---@param encounter Encounter
---@param data { red_count: number, blue_count: number, spectator_count: number, battle_name: string }
function encounter_init(encounter, data)
  print(data.battle_name)

  -- init timers
  Timers.CardSelectTimer.init(encounter)
  Timers.TurnTimer.init(encounter)
  Timers.AfkTimer.init(encounter)
  HitDamageJudge.init(encounter)

  SpectatorFun.init(encounter)

  encounter:set_turn_limit(10)
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
  end

  -- entity to init players on the first frame they're made available
  local entity = Artifact.new()

  entity.on_spawn_func = function()
    handle_team_disparity()

    entity:erase()
  end

  Field.spawn(entity, 0, 0)
end

math.randomseed()

local Crowns = require("scripts/tournament/crowns")
local Arena = require("scripts/tournament/arena")
local Direction = require("scripts/libs/direction")

---@type TournamentStructures
local structures = require("scripts/tournament/structures")
local TournamentTeam = structures.TournamentTeam
local DoubleElimination = structures.DoubleElimination

local BREAK_TIME = 10 -- in seconds

local area_id = "default"

---@type string[][]
local signed_up = {
  { "a" },
  { "b" }
}

---@class ContestantData
---@field id Net.ActorId
---@field name string
---@field prev_x number?
---@field prev_y number?
---@field prev_direction? string

---@type table<string, ContestantData>
local contestant_map = {}
---@type table<string, TournamentTeam>
local team_map = {}
---@type DoubleElimination
local tournament
---@type [TournamentTeam, TournamentTeam]
local arena_teams = {}
local started = false
local arena = Arena.find_arenas(area_id)[1]
---@type function?
local reset_callback

local function set_area_message(message)
  Net.set_area_name(area_id, message)
end

local function initialize_tournament()
  local teams = {}

  for _, members in ipairs(signed_up) do
    local team = TournamentTeam.new(members)

    for _, name in ipairs(members) do
      team_map[name] = team
    end

    teams[#teams + 1] = team
  end

  tournament = DoubleElimination.new(teams)
  set_area_message("Waiting")
end

initialize_tournament()

local function all_connected()
  for _, names in ipairs(signed_up) do
    for _, name in ipairs(names) do
      if not contestant_map[name] then
        return false
      end
    end
  end
  return true
end

---@param list any[]
local function includes(list, value)
  for _, v in ipairs(list) do
    if value == v then
      return true
    end
  end

  return false
end

local function pick_random_team()
  local team = tournament:pluck_random_team()
  print("Selected " .. team:to_string())
  return team
end

local function summon_contestant(name, warp_x, warp_y, warp_z, facing_direction)
  local contestant = contestant_map[name]

  if not contestant then
    return
  end

  local position = Net.get_player_position(contestant.id)
  contestant.prev_x = position.x
  contestant.prev_y = position.y
  contestant.prev_direction = Net.get_player_direction(contestant.id)

  Net.lock_player_input(contestant.id)
  Net.teleport_player(contestant.id, true, warp_x, warp_y, warp_z, facing_direction)

  return contestant
end

---@param contestant ContestantData
local function return_contestant(contestant)
  if not contestant.prev_x then
    -- never moved this player, may occur if the contestant disconnects too quickly
    return
  end

  Net.teleport_player(contestant.id, true, contestant.prev_x, contestant.prev_y, 0, contestant.prev_direction)
  contestant.prev_x = nil
  contestant.prev_y = nil
  contestant.prev_direction = nil

  Net.unlock_player_input(contestant.id)
end

local function resolve_winner()
  local complete, winning_team = tournament:declare_winner()

  if not complete then
    return complete
  end

  set_area_message("Tournament Over")
  Crowns.revoke_crowns()

  if not winning_team then
    -- no winning_team? someone must have disconnected
    print("No winner for this tournament?")
    return complete
  end

  print("Tournament Winner: " .. winning_team:to_string())

  for _, name in ipairs(winning_team.members) do
    local contestant = contestant_map[name]

    if contestant then
      Crowns.award_crown(contestant.id, "ROYAL CROWN")
    end
  end

  return complete
end

local prepare_next_battle = Async.create_function(function()
  set_area_message("Preparing")
  print("Preparing next battle")

  -- select teams immediately to handle reset
  arena_teams[1] = pick_random_team()
  arena_teams[2] = pick_random_team()

  -- set up callback for resetting
  local reset = false
  reset_callback = function()
    reset = true
  end

  -- pan the camera towards the field
  local SLIDE_TIME = 0.5

  for _, id in ipairs(Net.list_players(arena.area_id)) do
    Net.slide_player_camera(id, arena.center_x, arena.center_x, arena.z, SLIDE_TIME)
  end

  -- wait for camera
  Async.await(Async.sleep(SLIDE_TIME))

  -- summoning players to the arena

  ---@param team TournamentTeam
  local summon_team = function(team, x_offset, facing_direction)
    local x = arena.center_x + x_offset

    local MAX_PLAYER_DIST = 1.25

    local y_start = arena.center_y + MAX_PLAYER_DIST / 2
    local y_step = -MAX_PLAYER_DIST / (#team.members - 1)

    if #team.members == 1 then
      y_start = arena.center_y
      y_step = 0
    end

    for i, name in ipairs(team.members) do
      local y = y_start + (i - 1) * y_step

      summon_contestant(name, x, y, arena.z, facing_direction)

      Async.await(Async.sleep(0.25))

      -- check for reset before continuing
      if reset then
        return
      end
    end
  end

  summon_team(arena_teams[1], -1, Direction.DOWN_RIGHT)

  -- check for reset before continuing
  if reset then
    return
  end

  summon_team(arena_teams[2], 1, Direction.UP_LEFT)

  -- let people take it in
  Async.await(Async.sleep(1))

  -- check for reset before continuing
  if reset then
    return
  end

  arena:start_countdown(function()
    set_area_message("Fight!")

    -- gather players for battle
    local list = {}

    -- put contestants at the front
    for _, team in ipairs(arena_teams) do
      for _, name in ipairs(team.members) do
        local contestant = contestant_map[name]

        if contestant then
          list[#list + 1] = contestant.id
        end
      end
    end

    -- load spectators
    for _, id in ipairs(Net.list_players(area_id)) do
      local name = Net.get_player_name(id)
      local team = team_map[name]

      if not includes(arena_teams, team) then
        list[#list + 1] = id
      end
    end

    print("Initiating battle: " .. arena_teams[1]:to_string() .. " vs " .. arena_teams[2]:to_string())

    Net.initiate_netplay(
      list,
      "/server/mods/tournament",
      {
        red_count = #arena_teams[1].members,
        blue_count = #arena_teams[2].members
      }
    )
  end)
end)

local function start_break()
  if resolve_winner() then
    return
  end

  set_area_message("Break: " .. BREAK_TIME .. "s")

  Async.sleep(BREAK_TIME).and_then(function()
    -- update bracket in case something happened during the break
    if resolve_winner() then
      return
    end

    Crowns.revoke_crowns()

    prepare_next_battle()
  end)
end

local function start()
  started = true
  start_break()
end


Net:on("player_join", function(event)
  local name = Net.get_player_name(event.player_id)

  print(name .. " joined")

  if not contestant_map[name] and team_map[name] then
    contestant_map[name] = {
      id = event.player_id,
      name = name,
    }

    local team = team_map[name]
    team.connected_count = team.connected_count + 1

    if not started and all_connected() then
      start()
    end
  end
end)

local function reset()
  if reset_callback then
    reset_callback()
    reset_callback = nil
  end

  arena:reset()

  -- return contestants if they haven't already been returned
  for _, team in ipairs(arena_teams) do
    for _, name in ipairs(team.members) do
      local contestant = contestant_map[name]

      if contestant then
        Net.unlock_player_camera(contestant.id)
        return_contestant(contestant)
      end
    end
  end
end

Net:on("player_disconnect", function(event)
  local name = Net.get_player_name(event.player_id)
  local contestant = contestant_map[name]

  print(name .. " disconnected")

  if not contestant or contestant.id ~= event.player_id then
    return
  end

  contestant_map[name] = nil

  local team = team_map[name]

  team.connected_count = team.connected_count - 1

  if not started or team.connected_count > 0 then
    return
  end

  -- disqualify team for disconnecting during the tournament
  tournament:disqualify_team(team)

  -- reset the arena and advance the opponent team if this team was set to fight
  if includes(arena_teams, team) then
    local opponent_team

    if arena_teams[1] == team then
      opponent_team = arena_teams[2]
    else
      opponent_team = arena_teams[1]
    end

    if opponent_team then
      tournament:advance_team(opponent_team)
    end

    reset()
  end
end)

Net:on("battle_results", function(event)
  Net.unlock_player_camera(event.player_id)

  local name = Net.get_player_name(event.player_id)
  local contestant = contestant_map[name]

  if not contestant or not contestant.prev_x then
    return
  end

  if event.ran then
    print(name .. " forfeited")
  elseif event.health > 0 and arena_teams[1] then
    local team = team_map[name]

    if not team then
      error()
    end

    print("Winner: " .. team:to_string())

    -- set area message and resolve losing team
    local losing_team

    if team == arena_teams[1] then
      set_area_message("Red Wins")
      losing_team = arena_teams[2]
    else
      set_area_message("Blue Wins")
      losing_team = arena_teams[1]
    end

    -- see if we should allow the losing team into the losers bracket
    losing_team.chances = losing_team.chances - 1

    if losing_team.chances > 0 then
      tournament.losers_bracket:advance_team(losing_team)
    end

    -- reset arena
    arena:reset()
    arena_teams[1] = nil
    arena_teams[2] = nil

    -- advance winning team
    tournament:advance_team(team)

    -- award crowns
    for _, member_name in ipairs(team.members) do
      local contestant = contestant_map[member_name]

      if contestant then
        Crowns.award_crown(contestant.id, "CROWN")
      end
    end

    start_break()
  end

  Async.sleep(0.5).and_then(function()
    return_contestant(contestant)
  end)
end)

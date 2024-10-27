---@param list any[]
local function includes(list, value)
  for _, v in ipairs(list) do
    if value == v then
      return true
    end
  end

  return false
end

---@class TournamentTeam
---@field members string[]
---@field connected_count number
---@field win_count number
---@field chances number
local TournamentTeam = {}
TournamentTeam.__index = TournamentTeam

---@param members string[]
---@return TournamentTeam
function TournamentTeam.new(members)
  local team = {
    members = members,
    connected = {},
    connected_count = 0,
    win_count = 0,
    chances = 2
  }

  setmetatable(team, TournamentTeam)

  return team
end

function TournamentTeam:to_string()
  return "[ " .. table.concat(self.members, ", ") .. " ]"
end

---@class TournamentMatch
---@field red_team TournamentTeam
---@field blue_team TournamentTeam
---@field teams TournamentTeam[]
---@field player_accounting table<string, boolean>
---@field result_count number
---@field total_players number
local TournamentMatch = {}
TournamentMatch.__index = TournamentMatch

function TournamentMatch.new(red_team, blue_team)
  ---@type TournamentMatch
  local match = {
    red_team = red_team,
    blue_team = blue_team,
    teams = { red_team, blue_team },
    player_accounting = {},
    result_count = 0,
    total_players = #red_team.members + #blue_team.members
  }
  setmetatable(match, TournamentMatch)

  return match
end

---Track players losing or disconnecting during a battle
---@param member string
function TournamentMatch:mark_exit(member)
  if self.player_accounting[member] then
    -- already marked
    return
  end

  local team

  for _, t in ipairs(self.teams) do
    if includes(t.members, member) then
      team = t
      break
    end
  end

  if not team then
    return
  end

  self.player_accounting[member] = true
  self.result_count = self.result_count + 1
end

---Undo a tracked exit, in case the player came back in time to start the battle
---@param member string
function TournamentMatch:unmark_exit(member)
  if self.player_accounting[member] then
    self.player_accounting[member] = nil
    self.result_count = self.result_count - 1
  end
end

---@class TournamentBracket
---@field current TournamentTeam[]
---@field advancing TournamentTeam[]
local TournamentBracket = {}
TournamentBracket.__index = TournamentBracket

---@return TournamentBracket
function TournamentBracket.new()
  local bracket = {
    current = {},
    advancing = {}
  }
  setmetatable(bracket, TournamentBracket)
  return bracket
end

---@param team TournamentTeam
function TournamentBracket:advance_team(team)
  self.advancing[#self.advancing + 1] = team
end

function TournamentBracket:advance()
  -- advance left over teams
  for _, team in ipairs(self.current) do
    self.advancing[#self.advancing + 1] = team
  end

  self.current = self.advancing
  self.advancing = {}
end

function TournamentBracket:remaining_teams()
  return self.current
end

---@param team TournamentTeam
function TournamentBracket:disqualify_team(team)
  for i, t in ipairs(self.current) do
    if t == team then
      table.remove(self.current, i)
      break
    end
  end

  for i, t in ipairs(self.advancing) do
    if t == team then
      table.remove(self.advancing, i)
      break
    end
  end
end

---@return TournamentTeam
function TournamentBracket:pluck_random_team()
  return table.remove(self.current, math.random(#self.current))
end

---Simple single-elimination tournament with randomized / unfair "bye"
---@class SingleElimination
---@field bracket TournamentBracket
---@field teams TournamentTeam[]
local SingleElimination = {}
SingleElimination.__index = SingleElimination

---@param teams TournamentTeam[]
function SingleElimination.new(teams)
  local bracket = TournamentBracket.new()
  bracket.current = table.pack(table.unpack(teams))

  local se = {
    bracket = bracket,
    teams = teams
  }
  setmetatable(se, SingleElimination)
  return se
end

function SingleElimination:round_name()
  local total_round_teams = #self.bracket.advancing * 2 + #self.bracket.current

  if total_round_teams == 2 then
    return "Grand Finals"
  elseif total_round_teams <= 4 then
    return "Semi-Finals"
  end

  return "Elimination"
end

---@param team TournamentTeam
function SingleElimination:advance_team(team)
  self.bracket:advance_team(team)
end

---@param team TournamentTeam
function SingleElimination:try_second_chance(team)
  -- no second chances in a single elimination tournament
end

function SingleElimination:pluck_random_team()
  return self.bracket:pluck_random_team()
end

function SingleElimination:disqualify_team(team)
  self.bracket:disqualify_team(team)
end

---Call before resolving the next battle.
---This function additionally resolves the active bracket.
---
---Returns true if the tournament is over, a winning team is not guaranteed
---@return boolean, TournamentTeam?
function SingleElimination:declare_winner()
  if #self.bracket:remaining_teams() > 1 then
    -- we have enough teams to start battling
    return false
  end

  self.bracket:advance()

  if #self.bracket:remaining_teams() == 1 then
    -- just one player left, declare winner
    local winning_team = self.bracket:pluck_random_team()

    return true, winning_team
  elseif #self.bracket:remaining_teams() == 0 then
    -- no players left? someone must have disconnected
    return true
  end

  return false
end

---@class DoubleElimination
---@field active_bracket TournamentBracket
---@field winners_bracket TournamentBracket
---@field losers_bracket TournamentBracket
---@field teams TournamentTeam[]
local DoubleElimination = {}
DoubleElimination.__index = DoubleElimination

---@param teams TournamentTeam[]
function DoubleElimination.new(teams)
  local winners_bracket = TournamentBracket.new()
  local losers_bracket = TournamentBracket.new()

  winners_bracket.current = table.pack(table.unpack(teams))

  -- handle an odd number of teams
  if #winners_bracket:remaining_teams() % 2 == 1 then
    local team = winners_bracket:pluck_random_team()
    losers_bracket:advance_team(team)
  end

  local de = {
    active_bracket = winners_bracket,
    winners_bracket = winners_bracket,
    losers_bracket = losers_bracket,
    teams = teams
  }

  setmetatable(de, DoubleElimination)

  return de
end

function DoubleElimination:round_name()
  local winners_round_teams = #self.winners_bracket.advancing * 2 + #self.winners_bracket.current
  local losers_round_teams = #self.losers_bracket.advancing * 2 + #self.losers_bracket.current

  if self.active_bracket == self.losers_bracket then
    if losers_round_teams == 2 and winners_round_teams <= 2 then
      return "Semi-FinalsL"
    end

    return "EliminationL"
  end

  if winners_round_teams == 2 and losers_round_teams == 0 then
    return "Grand Finals"
  elseif winners_round_teams == 2 then
    return "Semi-Finals"
  end

  return "Elimination"
end

---@param team TournamentTeam
function DoubleElimination:advance_team(team)
  self.active_bracket:advance_team(team)
end

---@param team TournamentTeam
function DoubleElimination:try_second_chance(team)
  if team.connected_count == 0 then
    return
  end

  team.chances = team.chances - 1

  if team.chances > 0 then
    self.losers_bracket:advance_team(team)
  end
end

function DoubleElimination:pluck_random_team()
  return self.active_bracket:pluck_random_team()
end

function DoubleElimination:disqualify_team(team)
  self.winners_bracket:disqualify_team(team)
  self.losers_bracket:disqualify_team(team)
end

---Call before resolving the next battle.
---This function additionally resolves the active bracket.
---
---Returns true if the tournament is over, a winning team is not guaranteed
---@return boolean, TournamentTeam?
function DoubleElimination:declare_winner()
  for _ = 1, 2 do
    if #self.active_bracket:remaining_teams() > 1 then
      -- we have enough teams to start battling
      return false
    end

    -- swap to the other bracket
    if self.active_bracket == self.winners_bracket then
      self.active_bracket = self.losers_bracket
    else
      self.active_bracket = self.winners_bracket
    end

    self.active_bracket:advance()
  end

  if #self.active_bracket:remaining_teams() > 1 then
    return false
  end

  -- not enough players for a match still
  -- merge winners and losers brackets
  self.active_bracket = self.winners_bracket

  if #self.losers_bracket:remaining_teams() > 0 then
    local team = self.losers_bracket:pluck_random_team()
    self.active_bracket:advance_team(team)
  end

  self.active_bracket:advance()

  if #self.active_bracket:remaining_teams() == 1 then
    -- just one player left, declare winner
    local winning_team = self.active_bracket:pluck_random_team()

    return true, winning_team
  elseif #self.active_bracket:remaining_teams() == 0 then
    -- no players left? someone must have disconnected
    return true
  end

  return false
end

---@class TournamentStructures
local TournamentStructures = {
  includes = includes,
  TournamentTeam = TournamentTeam,
  TournamentMatch = TournamentMatch,
  TournamentBracket = TournamentBracket,
  SingleElimination = SingleElimination,
  DoubleElimination = DoubleElimination
}

return TournamentStructures

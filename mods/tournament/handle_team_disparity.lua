---@param field Field
---@param team Team
---@return Tile?
local function find_empty_boundary_tile(field, team)
  local opponent_tile_encountered = false
  local last_team_tile

  for x = 1, field:width() - 1 do
    local tile = field:tile_at(x, 1) --[[@as Tile]]

    if tile:team() ~= team then
      opponent_tile_encountered = true

      if last_team_tile then
        break
      end
    else
      last_team_tile = tile

      if opponent_tile_encountered then
        break
      end
    end
  end

  if last_team_tile then
    for y = 1, field:height() - 1 do
      local tile = field:tile_at(last_team_tile:x(), y) --[[@as Tile]]

      if not tile:is_reserved() then
        return tile
      end
    end
  end
end

---@param field Field
local function handle_team_disparity(field)
  local teams = { Team.Red, Team.Blue, Team.Other }
  ---@type table<Team, Entity[]>
  local team_lists = {
    [Team.Red] = {},
    [Team.Blue] = {},
    [Team.Other] = {}
  }

  field:find_players(function(player)
    local players = team_lists[player:team()]
    players[#players + 1] = player

    return false
  end)

  -- resolve base count
  local base_count = math.maxinteger
  local largest_count = 0

  for _, team in ipairs(teams) do
    local player_count = #team_lists[team]

    if player_count > 0 then
      base_count = math.min(base_count, player_count)
      largest_count = math.max(largest_count, player_count)
    end
  end

  -- check for equal teams
  local equal_teams = true

  for _, team in ipairs(teams) do
    local player_count = #team_lists[team]

    if player_count > 0 and player_count ~= base_count then
      equal_teams = false
      break
    end
  end

  if equal_teams then
    -- teams are equal, nothing to do
    return
  end

  -- try to handle disparity
  for _, team in ipairs(teams) do
    local players = team_lists[team]

    if #players == base_count then
      -- nerf area grabs by opponents using holes
      local tile = find_empty_boundary_tile(field, team)

      if tile then
        tile:set_state(TileState.PermaHole)
      end

      -- provide status guard to the entire team
      local status_gaurd_flags = Hit.Freeze | Hit.Paralyze | Hit.Blind | Hit.Confuse

      for _, player in ipairs(players) do
        local status_guard = AuxProp.new():declare_immunity(status_gaurd_flags)
        player:add_aux_prop(status_guard)
      end
    end

    if #players ~= largest_count then
      local diff = largest_count - #players
      local hp_increase = diff * 1000 / #players

      for _, player in ipairs(players) do
        player:boost_max_health(hp_increase)
        player:set_health(player:health() + hp_increase)
      end
    end
  end
end

return handle_team_disparity

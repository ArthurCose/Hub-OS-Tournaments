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

  for _, team in ipairs(teams) do
    local players = team_lists[team]

    if #players > 0 then
      base_count = math.min(base_count, #players)
    end
  end

  -- try to handle disparity
  for _, team in ipairs(teams) do
    local players = team_lists[team]

    if #players == base_count then
      goto continue
    end

    local raw_multiplier = math.sqrt(base_count / #players)
    local inverse_multiplier = -math.ceil((1 - raw_multiplier) * 100) / 100

    for _, player in ipairs(players) do
      player:boost_max_health(player:max_health() * inverse_multiplier)
      local card_aux = AuxProp.new():increase_card_multiplier(inverse_multiplier)
      player:add_aux_prop(card_aux)
    end

    ::continue::
  end
end

return handle_team_disparity

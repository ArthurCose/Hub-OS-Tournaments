math.randomseed()

local area_id = "default"
local width = Net.get_layer_width(area_id)
local height = Net.get_layer_height(area_id)
local target_layer = 0

local function valid_gid(gid)
  -- match the gid for platform.tsx in the default area
  return gid >= 10
end

Net:on("player_request", function(event)
  local x, y

  repeat
    x = math.random(width) - 1
    y = math.random(height) - 1
  until valid_gid(Net.get_tile(area_id, x, y, target_layer).gid)

  Net.transfer_player(event.player_id, "default", true, x + 0.5, y + 0.5, target_layer)
  Net.provide_package_for_player(event.player_id, "/server/mods/tournament")
end)

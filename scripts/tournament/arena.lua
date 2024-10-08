---@class Arena
---@field area_id string
---@field x number
---@field y number
---@field z number
---@field center_x number
---@field center_y number
---@field cancel_callback function?
---@field countdown_bots Net.ActorId[]
local Arena = {}
Arena.__index = Arena

local bot_offsets = {
  { -1.5, -1 },
  { -1.5, 1 },
  { 1.5,  -1 },
  { 1.5,  1 },
}

---@return Arena
function Arena:new(area_id, tile_x, tile_y, tile_z)
  local center_x = tile_x + 0.5
  local center_y = tile_y + 1

  local countdown_bots = {}

  for _, offset in ipairs(bot_offsets) do
    countdown_bots[#countdown_bots + 1] = Net.create_bot({
      area_id = area_id,
      warp_in = false,
      texture_path = "/server/assets/bots/pvp_countdown.png",
      animation_path = "/server/assets/bots/pvp_countdown.animation",
      solid = false,
      x = center_x + offset[1],
      y = center_y + offset[2],
      z = tile_z
    })
  end

  local arena = {
    area_id = area_id,
    center_x = center_x,
    center_y = center_y,
    x = tile_x - 1,
    y = tile_y,
    z = tile_z,
    fight_active = false,
    red_players = {},
    blue_players = {},
    countdown_bots = countdown_bots,
  }
  setmetatable(arena, self)

  return arena
end

---@param area_id string
---@return Arena[]
function Arena.find_arenas(area_id)
  local area_width = Net.get_layer_width(area_id)
  local area_height = Net.get_layer_height(area_id)
  local area_layer_count = Net.get_layer_count(area_id)

  local arena_tileset = Net.get_tileset(area_id, "/server/assets/tiles/battle_arena.tsx")
  local top_tile_gid = arena_tileset.first_gid + 1

  local arenas = {}

  for z = 0, area_layer_count - 1 do
    for y = 0, area_height - 1 do
      for x = 0, area_width - 1 do
        local tile = Net.get_tile(area_id, x, y, z)

        if tile.gid == top_tile_gid then
          arenas[#arenas + 1] = Arena:new(area_id, x, y, z)
        end
      end
    end
  end

  return arenas
end

function Arena:reset()
  if self.cancel_callback then
    self.cancel_callback()
    self.cancel_callback = nil
  end

  -- reset timer animations
  Net.synchronize(function()
    for _, bot_id in ipairs(self.countdown_bots) do
      Net.animate_bot(bot_id, "DEFAULT")
    end
  end)
end

---@param callback function
function Arena:start_countdown(callback)
  local cancelled = false
  self.cancel_callback = function()
    cancelled = true
  end

  -- animate bots to display timer
  Net.synchronize(function()
    for _, bot_id in ipairs(self.countdown_bots) do
      Net.animate_bot(bot_id, "COUNTDOWN")
    end
  end)

  -- start timing
  Async.sleep(3).and_then(function()
    if cancelled then
      return
    end

    Net.synchronize(function()
      -- fight! instead of the timer
      for _, bot_id in ipairs(self.countdown_bots) do
        Net.animate_bot(bot_id, "FIGHT")
      end

      callback()
    end)
  end)
end

return Arena

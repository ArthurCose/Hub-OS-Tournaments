local ALPHA_DECAY = 2 -- per frame, max is 255

---@class EmoteNode: Sprite
---@field _color Color

---@type EmoteNode[]
local emote_nodes = {}

local view_artifact = Artifact.new()
local view_sprite = view_artifact:sprite()
Field.spawn(view_artifact, 0, 0)

local view_component = view_artifact:create_component(Lifetime.Scene)

view_component.on_update_func = function()
  for i = #emote_nodes, 1, -1 do
    local node = emote_nodes[i]
    node._color.a = node._color.a - ALPHA_DECAY
    node:set_color(node._color)

    if node._color.a <= 0 then
      view_sprite:remove_node(node)

      -- swap remove
      emote_nodes[i] = emote_nodes[#emote_nodes]
      emote_nodes[#emote_nodes] = nil
    end
  end
end

local EMOTE_TEXTURE = Resources.load_texture("emotes.png")
local emotes_animator = Animation.new("emotes.animation")

local function spawn_emote(name)
  local node = view_sprite:create_node() --[[@as EmoteNode]]
  node:set_texture(EMOTE_TEXTURE)
  emotes_animator:set_state(name)
  emotes_animator:apply(node)

  node._color = node:color()
  node:set_offset(
    math.random(Tile:width(), (Field.width() - 2) * Tile:width()),
    math.random(-Tile:height() * 1.5, Tile:height() / 2 - 4)
  )
  node:set_never_flip(true)

  emote_nodes[#emote_nodes + 1] = node
end

return spawn_emote

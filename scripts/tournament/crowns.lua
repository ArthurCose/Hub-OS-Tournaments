local Crowns = {}

local crowns = {}

function Crowns.award_crown(player_id, animation_state)
  crowns[#crowns + 1] = Net.create_sprite({
    parent_id = player_id,
    parent_point = "EMOTE",
    texture_path = "/server/assets/crowns.png",
    animation_path = "/server/assets/crowns.animation",
    animation = animation_state
  })
end

function Crowns.revoke_crowns()
  for _, sprite_id in ipairs(crowns) do
    Net.delete_sprite(sprite_id)
  end
end

return Crowns

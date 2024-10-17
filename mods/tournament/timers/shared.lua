local SHADOW_COLOR = Color.new(82, 99, 115)
local TEXT_STYLE = TextStyle.new("THICK")
TEXT_STYLE.monospace = true

local Shared = {
  SHADOW_COLOR = SHADOW_COLOR,
  TEXT_STYLE = TEXT_STYLE,
}

print("shared.lua!")

-- reducing spawned entities
local artifact
function Shared.request_artifact(field)
  if artifact then
    return artifact
  end

  artifact = Artifact.new()
  field:spawn(artifact, 0, field:height() - 1)
  return artifact
end

return Shared

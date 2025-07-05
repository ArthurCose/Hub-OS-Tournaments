local ModDownloader = require("scripts/libs/mod_downloader")

local package_ids = {
  -- augments
  -- libraries
  "BattleNetwork6.Libraries.HitDamageJudge",
  "dev.konstinople.library.timers",
}

ModDownloader.maintain(package_ids)

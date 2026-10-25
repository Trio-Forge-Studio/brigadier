-- Runs one compiled docs example from .snippets/out for scripts/check-snippets.mjs. The examples run as a player
-- named Ann would.
local process = require("@lune/process")
local load = require("../test/lib/runtime")

load(".snippets/out", { "examples", process.args[1] }, { player = { Name = "Ann" } })

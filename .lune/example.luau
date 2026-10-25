-- Runs one compiled docs example for check-examples. The examples run as a player named Ann would.
local process = require("@lune/process")

require("@tooling/runtime")(".snippets/out", { globals = { player = { Name = "Ann" } } })("examples", process.args[1])

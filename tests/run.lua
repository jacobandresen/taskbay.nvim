-- The offline taskbay suite, runnable from any directory:
--   nvim --headless -u NONE -i NONE -l tests/run.lua
--   nvim --headless -u NONE -i NONE -l tests/run.lua core regressions/1-explorer-agent-window
-- runs only the named test files. Every file in tests/regressions/ runs after the main tests.
-- Loaded with the argument "list" it only returns the Lua test names (coverage.lua uses them).
local dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h")
local tests = { "helpers", "terminal", "tasks", "core", "editor", "fields", "copy", "delete", "remote", "layout", "harness_helpers", "e2e", "github" }
local regressions = vim.fn.globpath(dir .. "/regressions", "*.lua", false, true)
table.sort(regressions)
for _, path in ipairs(regressions) do tests[#tests + 1] = "regressions/" .. vim.fn.fnamemodify(path, ":t:r") end
if ... == "list" then return tests end
-- nvim -l passes its script arguments in the global arg table.
local selected = vim.list_slice(_G.arg or {}, 1)

local function fail(message)
  io.stderr:write(message .. "\n")
  vim.cmd("cquit 1")
end
if not vim.uv.fs_stat(dir .. "/../agents/pi/node_modules/pi-subagents/bundle/index.js") then
  fail("The pinned pi extension is missing: run :TaskbaySetup (npm ci --ignore-scripts --omit=dev in "
    .. vim.fs.normalize(dir .. "/../agents/pi") .. ")")
end
local function run(argv, env)
  local result = vim.system(argv, { text = true, env = env }):wait()
  io.stdout:write(result.stdout or "", result.stderr or "")
  if result.code ~= 0 then fail(table.concat(argv, " ") .. " failed") end
end
if #selected > 0 then
  for _, test in ipairs(selected) do
    if not vim.uv.fs_stat(dir .. "/" .. test .. ".lua") then fail("No test file tests/" .. test .. ".lua") end
  end
  tests = selected
end
for _, test in ipairs(tests) do
  run({ "timeout", "180", "nvim", "--headless", "-u", "NONE", "-i", "NONE", "-l", dir .. "/" .. test .. ".lua" })
  io.stdout:write("\n")
end
if #selected > 0 then vim.cmd("qa!") end
-- Inside the dotfiles that carry the plugin, the end-to-end flow also runs in their config.
if vim.uv.fs_stat(dir .. "/../../lua/config/lazy.lua") then
  run({ "timeout", "180", "nvim", "--headless", "-u", "NONE", "-i", "NONE", "-l", dir .. "/e2e.lua" },
    { TASKBAY_E2E_CONFIG = "dotfiles" })
  io.stdout:write(" (dotfiles config)\n")
end
run({ "timeout", "180", "python3", dir .. "/pi_extension.py" })
vim.cmd("qa!")

-- #4: with only the agent terminal left in the task tab, the diff picker opens files beside it.
local H = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h") .. "/harness.lua")({ name = "taskbay-regression-4" })
local lua, wait_for = H.lua, H.wait_for
vim.fn.writefile({ "changed" }, H.repo .. "/README.md")

H.run("regression #4: the diff picker opens beside a pinned agent window", function()
  H.boot()
  lua([[
    local root = ...
    local core = require("taskbay.core")
    _G.ws = { id = "regression-4", path = root, common = root .. "/.git", branch = "main", base_ref = "main",
      source = "github", repo = "test/repo", host = "github.com", number = 42, title = "Agent only" }
    core.workspaces[ws.id] = ws
    core.open(ws)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_call(buf, function() _G.agent_job = vim.fn.jobstart({ "sleep", "30" }, { term = true }) end)
    _G.agent_buf = buf
    core.jobs[ws.id] = { buf = buf, channel = agent_job, activity = "idle" }
    core.show(ws)
    vim.cmd.stopinsert()
  ]], H.repo)
  H.layout("agent_only")
  H.diff(42, "README.md")
  wait_for("README.md must open", "return vim.api.nvim_buf_get_name(0) == ...", 5000, H.repo .. "/README.md")
  assert(lua("return #vim.fn.win_findbuf(agent_buf) == 1"), "The agent terminal must still be shown")
  H.invariants()
  lua("vim.fn.jobstop(agent_job); require('taskbay.core').jobs[ws.id] = nil")
end)

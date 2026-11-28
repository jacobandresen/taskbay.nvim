-- #25 (and #14): F6 in a standalone agent terminal hides it, also when Neovim's working
-- directory is outside the repository the agent was opened for.
local H = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h") .. "/harness.lua")({ name = "taskbay-regression-25" })
local lua, wait_for, keys = H.lua, H.wait_for, H.keys
local elsewhere = H.temp .. "/elsewhere"
vim.fn.mkdir(elsewhere, "p")
-- A pi that just waits, ahead of the harness's scripted one (which needs a task's status file).
vim.fn.mkdir(H.temp .. "/standalone-bin", "p")
vim.fn.writefile({ "#!/bin/sh", "trap 'exit 0' TERM HUP", "while :; do sleep 1; done" }, H.temp .. "/standalone-bin/pi")
assert(vim.uv.fs_chmod(H.temp .. "/standalone-bin/pi", 493))

H.run("regression #25: F6 hides the standalone agent terminal", function()
  H.boot({ cwd = elsewhere })
  lua([[
    local bin, file = ...
    vim.env.PATH = bin .. ":" .. vim.env.PATH
    vim.cmd.edit(vim.fn.fnameescape(file))
    require("taskbay.terminal").toggle()
    _G.agent_buf = vim.api.nvim_get_current_buf()
  ]], H.temp .. "/standalone-bin", H.repo .. "/README.md")
  assert(lua("return vim.bo[agent_buf].buftype") == "terminal", "The agent terminal must open")
  wait_for("Terminal input", "return vim.fn.mode() == 't'")
  keys("<F6>")
  wait_for("F6 must hide the agent terminal", "return #vim.fn.win_findbuf(agent_buf) == 0")
  assert(lua("return #Snacks.terminal.list()") == 1, "F6 must not start a second agent")
  keys("<F6>")
  wait_for("F6 must show the same agent again", "return vim.api.nvim_get_current_buf() == agent_buf")
  assert(lua("return #Snacks.terminal.list()") == 1, "Showing it again must not start another agent")
  lua("vim.cmd.stopinsert(); for _, t in ipairs(Snacks.terminal.list()) do vim.fn.jobstop(vim.bo[t.buf].channel) end")
end)

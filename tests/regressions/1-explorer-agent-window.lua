-- #1: choosing a file in the Snacks explorer or a picker must not replace the agent terminal.
local T = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h") .. "/lib.lua")({ name = "regression-1" })
local core = require("taskbay.core")
T.snacks()
local repository = T.create_repository("repo")
local workspace = {
  id = "regression-1", path = repository.root, common = repository.common, branch = "main", base_ref = "main",
  source = "local", repo = "repo", host = "local", number = 1, title = "Explorer and agent",
}
core.workspaces[workspace.id] = workspace

T.case("picked files open in the task window, not over the agent", function()
  core.open(workspace)
  local job = T.job(workspace)
  core.show(workspace)
  local agent = vim.fn.win_findbuf(job.buf)[1]
  assert(vim.wo[agent].winfixbuf, "The agent window must be pinned to its terminal")
  local main = require("snacks.picker.core.main").new():find()
  assert(main ~= agent and vim.api.nvim_win_get_buf(main) ~= job.buf,
    "Snacks must choose the task window for picked files")
  T.fails(function() vim.cmd.edit(vim.fn.fnameescape(repository.root .. "/README.md")) end, "E1513")
  assert(vim.api.nvim_win_get_buf(agent) == job.buf, "The agent terminal must still be shown")
end)

T.done("regression #1: picked files keep out of the agent window")

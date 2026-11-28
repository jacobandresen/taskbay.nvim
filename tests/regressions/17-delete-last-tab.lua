-- #17: deleting works when the task tab is the only tab, and a refused delete leaves the agent running.
local T = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h") .. "/lib.lua")({ name = "regression-17" })
local core, tasks = require("taskbay.core"), require("taskbay.store")
local repository = T.create_repository("repo")
_G.LazyVim = { root = function() return repository.root end }
local function prepare(title)
  local task = tasks.create(repository, title)
  return T.await(function() return core.prepare(repository, task, "main", true) end)
end

T.case("delete from the only tab", function()
  local workspace = prepare("Only tab")
  core.open(workspace)
  vim.cmd("tabonly!")
  T.job(workspace)
  core.show(workspace)
  vim.cmd.stopinsert()
  T.await(function() core.delete(workspace) end)
  assert(not vim.uv.fs_stat(workspace.path), "The worktree must be deleted")
  assert(#vim.api.nvim_list_tabpages() == 1 and vim.t.taskbay_workspace == nil, "One empty tab must remain")
end)

T.case("a refused delete keeps the agent running", function()
  local workspace = prepare("Modified file")
  core.open(workspace)
  local job = T.job(workspace)
  vim.cmd.edit(vim.fn.fnameescape(workspace.path .. "/README.md"))
  vim.api.nvim_buf_set_lines(0, -1, -1, false, { "unsaved" })
  T.reported(function() core.delete(workspace) end, "Save or discard modified files")
  assert(not job.exited, "The agent must keep running")
  vim.bo.modified = false
end)

T.done("regression #17: delete from the last tab, and refusals before stopping")

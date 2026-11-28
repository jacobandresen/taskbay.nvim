-- #10: finishing a task commits every change in its worktree, including files written while the
-- finish dialog was open or before its agent stopped.
local T = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h") .. "/lib.lua")({ name = "regression-10" })
local core, tasks = require("taskbay.core"), require("taskbay.store")
local repository = T.create_repository("repo")
_G.LazyVim = { root = function() return repository.root end }

local function finish_with_late_write(title, with_agent)
  local task = tasks.create(repository, title)
  local workspace = T.await(function() return core.prepare(repository, task, "main", true) end)
  if with_agent then T.job(workspace) end
  T.choose({ {
    match = "Worktree: clean",
    before = function() T.write(workspace.path .. "/late.txt", { title }) end,
    answer = with_agent and "Stop the agent, commit and merge" or "Commit and merge",
  } })
  T.await(function() core.finish(workspace) end)
  assert(workspace.finished, "The task must be finished")
  assert(vim.uv.fs_stat(repository.root .. "/late.txt"), "late.txt must be merged into main")
  assert(T.git(workspace.path, "status", "--porcelain") == "", "Nothing may be left uncommitted")
  T.git(repository.root, "rm", "-q", "late.txt")
  T.git(repository.root, "commit", "-q", "-m", "Remove late.txt")
end

T.case("a file written while the dialog is open is committed", function()
  finish_with_late_write("Late write", false)
end)

T.case("a file written before the running agent stopped is committed", function()
  finish_with_late_write("Late agent write", true)
end)

T.done("regression #10: finish commits changes made while it waited")

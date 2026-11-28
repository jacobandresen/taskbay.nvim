-- Run: timeout 60 nvim --headless -u NONE -i NONE -l tests/delete.lua
local T = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/lib.lua")({ name = "delete" })
local core = require("taskbay.core")
local tasks = require("taskbay.store")
local root = T.create_repository("repo", { README = { "test" } }).root
_G.LazyVim = { root = function() return root end }
local repo = T.await(function() return core.repository(root) end)

local function gone(path) return not vim.uv.fs_stat(path) end
local function registered(path)
  for _, entry in ipairs(T.await(function() return core.worktrees(repo.root) end)) do
    if entry.path == path then return true end
  end
  return false
end

T.case("a pending task file", function()
  local pending = tasks.create(repo, "Pending deletion")
  local path = tasks.file(pending)
  tasks.delete(pending)
  assert(gone(path))
end)

T.case("a prepared worktree with its state", function()
  local prepared = tasks.create(repo, "Prepared deletion")
  local workspace = T.await(function() return core.prepare(repo, prepared, "HEAD", true) end)
  local task_path, worktree_path, state_path = tasks.file(prepared), workspace.path, core.directory(workspace)
  T.await(function() return core.delete(workspace) end)
  assert(gone(task_path), "Task file was not deleted")
  assert(gone(worktree_path), "Worktree was not deleted")
  assert(gone(state_path), "Workspace state was not deleted")
  assert(core.workspaces[workspace.id] == nil and core.jobs[workspace.id] == nil)
  assert(#tasks.list(repo) == 0)
  assert(not registered(worktree_path))
end)

-- A workspace whose worktree and task file were already removed externally
-- (stale dashboard row) must still delete cleanly.
T.case("a stale workspace", function()
  tasks.delete(tasks.create(repo, "Stale deletion"))
  local stale = tasks.create(repo, "Stale deletion 2")
  local workspace = T.await(function() return core.prepare(repo, stale, "HEAD", true) end)
  vim.fn.delete(workspace.path, "rf") -- remove without git worktree remove
  vim.uv.fs_unlink(tasks.file(workspace))
  T.await(function() return core.delete(workspace) end)
  assert(core.workspaces[workspace.id] == nil)
  assert(gone(core.directory(workspace)), "Stale workspace state was not deleted")
  assert(not registered(workspace.path))
end)

T.case("an already-missing task file", function()
  local missing = tasks.create(repo, "Already gone")
  vim.uv.fs_unlink(tasks.file(missing))
  T.await(function() return tasks.delete(missing) end)
end)

T.done("taskbay delete: pending files, prepared worktrees and persisted sessions passed")

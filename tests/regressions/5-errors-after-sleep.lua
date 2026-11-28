-- #5: errors raised in a task after it has waited (core.sleep, stop_wait) must reach the user.
local T = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h") .. "/lib.lua")({ name = "regression-5" })
local core, tasks = require("taskbay.core"), require("taskbay.store")
local repository = T.create_repository("repo")
_G.LazyVim = { root = function() return repository.root end }

T.case("an error after core.sleep is shown", function()
  T.reported(function()
    core.sleep(10)
    error("raised after sleeping", 0)
  end, "raised after sleeping")
end)

T.case("deleting a task with unsaved edits while its agent runs says why it stopped", function()
  local task = tasks.create(repository, "Unsaved edits")
  local workspace = T.await(function() return core.prepare(repository, task, "main", true) end)
  T.job(workspace)
  vim.cmd.edit(vim.fn.fnameescape(tasks.file(workspace)))
  vim.api.nvim_buf_set_lines(0, -1, -1, false, { "unsaved" })
  T.reported(function() core.delete(workspace) end, "Save or discard modified task buffers")
  assert(vim.uv.fs_stat(workspace.path), "The refused delete must keep the worktree")
  vim.bo.modified = false
end)

T.done("regression #5: errors after waiting reach the user")

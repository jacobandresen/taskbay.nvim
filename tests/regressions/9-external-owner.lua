-- #9: finish, delete and restart refuse a task whose agent runs in another Neovim.
local T = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h") .. "/lib.lua")({ name = "regression-9" })
local core, tasks = require("taskbay.core"), require("taskbay.store")
local repository = T.create_repository("repo")
_G.LazyVim = { root = function() return repository.root end }
local function prepare(title)
  local task = tasks.create(repository, title)
  return T.await(function() return core.prepare(repository, task, "main", true) end)
end

for _, action in ipairs({ "finish", "delete", "restart" }) do
  T.case(action .. " refuses", function()
    local workspace = prepare("Owned elsewhere " .. action)
    T.owner(workspace, "live")
    T.choose({}) -- the refusal comes before any dialog
    T.fails(function() T.await(function() core[action](workspace) end) end, "Another Neovim runs")
    assert(vim.uv.fs_stat(workspace.path), "The worktree must be kept")
    assert(vim.uv.fs_stat(core.directory(workspace) .. "/owner.json"), "The other editor's lock must be kept")
    T.owner(workspace, "dead") -- an abandoned lock no longer blocks
    if action == "finish" then
      T.choose({ { answer = "Commit and merge" } })
      T.await(function() core.finish(workspace) end)
      assert(workspace.finished)
    end
  end)
end

T.done("regression #9: tasks owned by another Neovim are left alone")

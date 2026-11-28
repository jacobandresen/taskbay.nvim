-- #18: an empty or corrupt owner.json left by a crash can be recovered; a fresh one is respected.
local T = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h") .. "/lib.lua")({ name = "regression-18" })
local core, tasks = require("taskbay.core"), require("taskbay.store")
local repository = T.create_repository("repo")
_G.LazyVim = { root = function() return repository.root end }
local function prepare(title)
  local task = tasks.create(repository, title)
  return T.await(function() return core.prepare(repository, task, "main", true) end)
end

local function damaged_lock(workspace, age)
  local path = core.directory(workspace) .. "/owner.json"
  T.write(path, { "" })
  T.corrupt(path, "empty")
  local time = os.time() - age
  assert(vim.uv.fs_utime(path, time, time))
  return path
end

T.case("an old corrupt lock is recovered", function()
  local workspace = prepare("Old lock")
  local path = damaged_lock(workspace, 60)
  T.choose({ { match = "Recover", answer = "Recover abandoned lock" } })
  local job = T.start(workspace)
  assert(core.read_json(path).pid == vim.fn.getpid(), "The lock must now belong to this editor")
  assert(T.await(function() return core.stop_wait(workspace, job) end))
end)

T.case("a fresh corrupt lock is left alone", function()
  local workspace = prepare("Fresh lock")
  damaged_lock(workspace, 0)
  T.choose({})
  T.fails(function() T.await(function() core.start(workspace) end) end, "unknown owner")
end)

T.done("regression #18: corrupt locks left by a crash are recoverable")

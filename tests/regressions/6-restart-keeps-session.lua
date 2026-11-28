-- #6: a restart that cannot start the agent keeps the saved conversation.
local T = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h") .. "/lib.lua")({ name = "regression-6" })
local core, tasks = require("taskbay.core"), require("taskbay.store")
local repository = T.create_repository("repo")
_G.LazyVim = { root = function() return repository.root end }
local function prepare(title)
  local task = tasks.create(repository, title)
  return T.await(function() return core.prepare(repository, task, "main", true) end)
end

T.case("restart at the agent limit keeps the session", function()
  T.configure({ max_agents = 1 })
  local a, b = prepare("Task A"), prepare("Task B")
  local job = T.start(a)
  assert(T.await(function() return core.stop_wait(a, job) end))
  a.finished = os.time()
  core.save(a)
  local before = T.saved(a)
  assert(before.session_file and before.started, "Task A must have a saved session")
  T.job(b)
  T.fails(function() T.await(function() core.restart(a) end) end, "Agent limit reached")
  local after = T.saved(a)
  assert(after.session_file == before.session_file and after.started == before.started
    and after.finished == before.finished and after.restarts == before.restarts and after.session == before.session,
    "The saved state must be unchanged: " .. vim.inspect({ before = before, after = after }))
end)

T.done("regression #6: a failed restart keeps the saved session")

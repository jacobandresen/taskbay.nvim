-- The shared test library checks itself. Run: timeout 60 nvim --headless -u NONE -i NONE -l tests/helpers.lua
local T = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/lib.lua")({ name = "helpers" })
local core = require("taskbay.core")
local hostile = dofile(T.plugin .. "/tests/fixtures/hostile.lua")
local repository = T.create_repository("repo", { ["a.txt"] = { "a" } })
local tasks = require("taskbay.store")

T.case("create_repository commits the files on main", function()
  assert(T.git(repository.root, "branch", "--show-current") == "main")
  assert(T.git(repository.root, "ls-files") == "a.txt")
  local other = T.create_repository("other")
  assert(other.root ~= repository.root and T.git(other.root, "ls-files") == "README.md")
end)

T.case("sh fails with the command's error output", function()
  T.fails(function() T.git(repository.root, "no-such-command") end, "no-such-command")
end)

T.case("await returns values and raises errors", function()
  assert(T.await(function() core.sleep(1) return 42 end) == 42)
  T.fails(function() T.await(function() error("inside", 0) end) end, "inside")
end)

T.case("reported sees errors core.task shows, and misses swallowed ones", function()
  T.reported(function() error("shown to the user", 0) end, "shown to the user")
  -- An error the code catches itself never reaches the user, so reported must fail on it.
  local ok = pcall(T.reported, function() pcall(error, "swallowed", 0) end, "swallowed", 500)
  assert(not ok, "reported must fail when the error never reaches the user")
end)

T.case("choose runs code while the dialog is open", function()
  local seen
  T.choose({ { match = "Proceed", before = function(message) seen = message end, answer = "Yes" } })
  assert(T.await(function() return core.choose({ "No", "Yes" }, "Proceed?") end) == "Yes" and seen == "Proceed?")
  T.choose({})
  T.fails(function() core.choose({ "No" }, "Surprise") end, "Unexpected dialog: Surprise")
  T.choose({ { match = "Other", answer = "No" } })
  T.fails(function() core.choose({ "No" }, "Surprise") end, "does not match")
  T.choose({})
end)

T.case("configure merges settings", function()
  T.configure({ max_agents = 1 })
  assert(core.settings().max_agents == 1 and core.settings().state_dir == T.temp .. "/state")
  T.configure({ max_agents = 3 })
end)

T.case("job is stopped by core.stop, start runs the pi stand-in", function()
  local task = tasks.create(repository, "Helper task")
  local workspace = T.await(function() return core.prepare(repository, task, "main", true) end)
  local job = T.job(workspace)
  assert(core.live() == 1)
  assert(T.await(function() return core.stop_wait(workspace, job) end), "core.stop must end a T.job")
  local started = T.start(workspace)
  assert(started.sequence and T.saved(workspace).started == true)
  assert(T.await(function() return core.stop_wait(workspace, started) end))
end)

T.case("owner writes another editor's lock", function()
  local workspace = { id = "owned" }
  local live = T.owner(workspace, "live")
  assert(vim.uv.kill(live, 0) == 0, "a live owner must be running")
  local dead = T.owner(workspace, "dead")
  assert(not vim.uv.kill(dead, 0), "a dead owner must have exited")
  assert(core.read_json(core.directory(workspace) .. "/owner.json").pid == dead)
end)

T.case("corrupt damages files", function()
  local path = T.temp .. "/state.json"
  local function read()
    local file = assert(io.open(path, "rb"))
    local data = file:read("a")
    file:close()
    return data
  end
  for kind, expected in pairs({ empty = "", truncate = '{"a"', garbage = '{"' }) do
    vim.fn.writefile({ '{"a":"b"}' }, path, "b") -- 9 bytes, no newline
    T.corrupt(path, kind)
    assert(read() == expected, kind .. ": " .. vim.inspect(read()))
  end
end)

T.case("hostile fixtures and write_tasks", function()
  assert(#hostile.names >= 8 and hostile.contents.end_of_paste[2]:find("\27[201~", 1, true))
  local broken = T.create_repository("broken")
  T.write_tasks(broken, "unpadded")
  assert(vim.uv.fs_stat(broken.root .. "/.tasks/10-b.md") and vim.uv.fs_stat(broken.root .. "/.tasks/009-a.md"))
  T.fails(function() T.write_tasks(broken, "nonsense") end, "No task layout nonsense")
end)

T.case("faults fail and delay chosen commands, and pass the rest on", function()
  T.faults()
  vim.env.TASKBAY_FAIL = "git commit@2;git tag"
  T.fails(function() T.git(repository.root, "tag", "v1") end, "injected failure: git tag v1")
  T.git(repository.root, "-c", "user.name=X", "commit", "-q", "--allow-empty", "-m", "first")
  T.fails(function() T.git(repository.root, "commit", "-q", "--allow-empty", "-m", "second") end, "injected failure")
  T.git(repository.root, "commit", "-q", "--allow-empty", "-m", "third")
  assert(T.git(repository.root, "log", "--format=%s", "-1") == "third")
  vim.env.TASKBAY_FAIL = nil
  vim.env.TASKBAY_SLOW = "git status=300ms"
  local start = vim.uv.hrtime()
  T.git(repository.root, "status")
  assert((vim.uv.hrtime() - start) / 1e6 >= 300, "git status must be delayed")
  vim.env.TASKBAY_SLOW = nil
  -- core.git goes through the wrapper too, so plugin code sees the injected failures.
  vim.env.TASKBAY_FAIL = "git rev-parse"
  T.fails(function() T.await(function() return core.git(repository.root, "rev-parse", "HEAD") end) end, "injected failure")
  vim.env.TASKBAY_FAIL = nil
end)

T.case("received returns what reached the pi stand-in", function()
  local task = tasks.create(repository, "Input task")
  local workspace = T.await(function() return core.prepare(repository, task, "main", true) end)
  local job = T.start(workspace)
  vim.api.nvim_chan_send(job.channel, "hello\n")
  assert(vim.wait(3000, function() return T.received(workspace):find("hello", 1, true) ~= nil end, 10),
    vim.inspect(T.received(workspace)))
  assert(T.await(function() return core.stop_wait(workspace, job) end))
end)

T.done("taskbay helpers: repositories, tasks, reported errors, dialogs, agents, owners, corruption and fixtures")

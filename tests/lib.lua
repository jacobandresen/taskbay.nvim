-- Shared helpers for taskbay's in-process tests. Load it with dofile, so tests/coverage.lua traces
-- the plugin code it runs:
--   local T = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/lib.lua")({ name = "core" })
-- opts.name: shown in failures; opts.settings: merged into vim.g.taskbay.
-- TASKBAY_TEST_KEEP=1 keeps the temporary directory of a failed run.
local uv = vim.uv
local dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")
local plugin = vim.fs.dirname(dir)

return function(opts)
opts = opts or {}
vim.opt.rtp:prepend(plugin)
vim.g.mapleader = " "
local T = { name = opts.name or "test", plugin = plugin, messages = {} }
-- Not vim.fn.tempname(): Neovim removes that directory on exit, which defeats TASKBAY_TEST_KEEP.
T.temp = assert(uv.fs_mkdtemp(uv.os_tmpdir() .. "/taskbay-" .. T.name .. "-XXXXXX"))
vim.g.taskbay = vim.tbl_extend("force", {
  state_dir = T.temp .. "/state",
  pi = { cmd = plugin .. "/tests/fixtures/pi_stub.py" },
}, opts.settings or {})
vim.notify = function(message) T.messages[#T.messages + 1] = tostring(message) end

local core = require("taskbay.core")
local failures, processes, script = {}, {}, nil

-- Shell -------------------------------------------------------------------------------------

-- Run argv; a non-zero exit fails the test with the command's error output. Returns trimmed stdout.
function T.sh(argv, cwd)
  local result = vim.system(argv, { cwd = cwd, text = true }):wait()
  assert(result.code == 0, table.concat(argv, " ") .. " (exit " .. result.code .. "): " .. (result.stderr or ""))
  return vim.trim(result.stdout or "")
end

function T.git(cwd, ...) return T.sh(vim.list_extend({ "git" }, { ... }), cwd) end

-- Write lines to path, creating its directories.
function T.write(path, lines)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile(lines, path)
end

-- Repositories ------------------------------------------------------------------------------

-- A new Git repository in T.temp/<name>: files (path -> lines) committed as the first commit on
-- main by a fixed test author. Returns the repository table core.prepare takes.
function T.create_repository(name, files)
  local root = T.temp .. "/" .. name
  vim.fn.mkdir(root, "p")
  T.git(root, "init", "-q", "-b", "main")
  T.git(root, "config", "user.name", "Test")
  T.git(root, "config", "user.email", "test@example.invalid")
  for path, lines in pairs(files or { ["README.md"] = { "# " .. name } }) do T.write(root .. "/" .. path, lines) end
  T.git(root, "add", "-A")
  T.git(root, "commit", "-q", "--allow-empty", "-m", "Initial")
  return { root = root, common = root .. "/.git", source = "local", repo = name, host = "local" }
end

-- Write a named layout from tests/fixtures/hostile.lua into the repository's .tasks/ directory.
function T.write_tasks(repository, layout)
  local files = assert(dofile(dir .. "/fixtures/hostile.lua").tasks[layout], "No task layout " .. layout)
  for name, lines in pairs(files) do T.write(repository.root .. "/.tasks/" .. name, lines) end
end

-- Tasks and errors --------------------------------------------------------------------------

-- Run fn in core.task, wait for it, and return its value or raise its error.
function T.await(fn, timeout)
  local done, result, failure = false
  core.task(function()
    local ok, value = pcall(fn)
    if ok then result = value else failure = value end
    done = true
  end)
  assert(vim.wait(timeout or 15000, function() return done end, 10),
    "Timed out; messages:\n" .. table.concat(T.messages, "\n"))
  if failure ~= nil then error(failure, 0) end
  return result
end

-- fn must raise an error containing text.
function T.fails(fn, text)
  local ok, err = pcall(fn)
  assert(not ok, "Expected an error containing " .. text)
  assert(tostring(err):find(text, 1, true), "Expected an error containing " .. text .. ", got " .. tostring(err))
end

function T.notified(text, from)
  for index = from or 1, #T.messages do
    if T.messages[index]:find(text, 1, true) then return true end
  end
  return false
end

-- Run fn through core.task exactly as a key press would (no pcall of our own) and require that
-- the user was shown a message containing text.
function T.reported(fn, text, timeout)
  local first, finished = #T.messages + 1, false
  core.task(function()
    fn()
    finished = true
  end)
  vim.wait(timeout or 5000, function() return finished or T.notified(text, first) end, 10)
  assert(T.notified(text, first), "Expected a message containing " .. text .. "; got:\n"
    .. table.concat(vim.list_slice(T.messages, first), "\n"))
end

-- Dialogs -----------------------------------------------------------------------------------

-- Replace core.choose with a script of expected dialogs, consumed in order. A step is
-- { match = text?, before = function(message, choices)?, answer = choice }; before runs while
-- the dialog is open and may yield.
function T.choose(steps)
  script = { steps = steps, next = 1 }
  core.choose = function(choices, message)
    local step = script.steps[script.next]
    assert(step, "Unexpected dialog: " .. tostring(message))
    script.next = script.next + 1
    assert(not step.match or tostring(message):find(step.match, 1, true),
      "Dialog does not match " .. vim.inspect(step.match) .. ": " .. tostring(message))
    if step.before then step.before(message, choices) end
    assert(vim.tbl_contains(choices, step.answer),
      "Dialog has no choice " .. vim.inspect(step.answer) .. ": " .. vim.inspect(choices))
    return step.answer
  end
end

-- Settings, agents and state ----------------------------------------------------------------

function T.configure(options) vim.g.taskbay = vim.tbl_extend("force", vim.g.taskbay, options) end

local function sleeper(seconds)
  local channel = vim.fn.jobstart({ "sleep", tostring(seconds or 30) })
  processes[#processes + 1] = channel
  return channel
end

-- A fake running agent: a terminal buffer running sleep, registered as the workspace's job.
-- core.stop ends it, and the job is then marked exited like a real one.
function T.job(workspace)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "hide"
  local job = { buf = buf, activity = "idle" }
  vim.api.nvim_buf_call(buf, function()
    job.channel = vim.fn.jobstart({ "sleep", "30" }, {
      term = true,
      on_exit = function() job.exited = true end,
    })
  end)
  processes[#processes + 1] = job.channel
  core.jobs[workspace.id] = job
  return job
end

-- Start the pi stand-in (tests/fixtures/pi_stub.py) through core.start and wait for its first status.
function T.start(workspace)
  T.await(function() core.start(workspace) end)
  local job = core.jobs[workspace.id]
  assert(vim.wait(5000, function() return job.sequence ~= nil or job.exited end, 10) and not job.exited,
    "The pi stand-in did not report a status; messages:\n" .. table.concat(T.messages, "\n"))
  return job
end

-- The workspace record as written to state_dir.
function T.saved(workspace) return core.read_json(core.directory(workspace) .. "/workspace.json") end

-- Write the workspace's owner.json as if another editor held it: "live" records a running
-- process, "dead" one that has exited.
function T.owner(workspace, kind)
  local pid
  if kind == "live" then
    pid = vim.fn.jobpid(sleeper(30))
  else
    local channel = vim.fn.jobstart({ "true" })
    pid = vim.fn.jobpid(channel)
    vim.fn.jobwait({ channel })
  end
  core.write(core.directory(workspace) .. "/owner.json", vim.json.encode({ token = "other-editor", run = "other", pid = pid }))
  return pid
end

-- Damage a file the way a crash or a full disk would: "empty", "truncate" (first half) or "garbage".
function T.corrupt(path, kind)
  local source = assert(io.open(path, "rb"))
  local data = source:read("a")
  source:close()
  local damaged = ({ empty = "", truncate = data:sub(1, math.floor(#data / 2)), garbage = '{"' })[kind]
  assert(damaged, "Unknown corruption " .. tostring(kind))
  local file = assert(io.open(path, "wb"))
  file:write(damaged)
  file:close()
end

-- Faults ----------------------------------------------------------------------------------------

-- Put tests/fixtures/fail.py in front of gh and git on this process's PATH. Then set
-- vim.env.TASKBAY_FAIL ("gh issue close", "git commit@2") or vim.env.TASKBAY_SLOW
-- ("git status=500ms") to fail or delay matching calls; see fail.py.
function T.faults(commands)
  local wrappers = T.temp .. "/faults"
  vim.fn.mkdir(wrappers, "p")
  for _, name in ipairs(commands or { "gh", "git" }) do
    local path = wrappers .. "/" .. name
    vim.fn.writefile({ "#!/bin/sh", "exec python3 " .. vim.fn.shellescape(dir .. "/fixtures/fail.py") .. " "
      .. vim.fn.shellescape(wrappers) .. " " .. name .. ' "$@"' }, path)
    assert(uv.fs_chmod(path, 493))
  end
  if not vim.startswith(vim.env.PATH, wrappers .. ":") then vim.env.PATH = wrappers .. ":" .. vim.env.PATH end
  return wrappers
end

-- Every byte the pi stand-in received on its terminal input for this workspace.
function T.received(workspace)
  local path = core.directory(workspace) .. "/paste.txt"
  if not uv.fs_stat(path) then return "" end
  local file = assert(io.open(path, "rb"))
  local data = file:read("a")
  file:close()
  return data
end

-- Snacks --------------------------------------------------------------------------------------

-- Load snacks.nvim (TASKBAY_SNACKS, else lazy.nvim's checkout) with the picker enabled.
function T.snacks()
  local path = vim.env.TASKBAY_SNACKS or (vim.fn.stdpath("data") .. "/lazy/snacks.nvim")
  assert(uv.fs_stat(path), "snacks.nvim not found at " .. path .. "; set TASKBAY_SNACKS")
  vim.opt.rtp:append(path)
  _G.Snacks = require("snacks")
  Snacks.setup({ picker = { enabled = true }, notifier = { enabled = false } })
  return Snacks
end

-- Running -------------------------------------------------------------------------------------

-- Run one named scenario. A failure is printed with the file and scenario names; later cases still run.
function T.case(name, fn)
  local ok, err = xpcall(fn, debug.traceback)
  if not ok then
    failures[#failures + 1] = name
    io.stderr:write(("%s: %s: %s\n"):format(T.name, name, tostring(err)))
  end
  return ok
end

-- Stop what the tests started, remove T.temp, report and exit the test editor.
function T.done(summary)
  if script and script.next <= #script.steps then
    failures[#failures + 1] = "dialogs"
    io.stderr:write(("%s: %d expected dialog(s) never appeared\n"):format(T.name, #script.steps - script.next + 1))
  end
  for id, job in pairs(core.jobs) do
    if not job.exited and job.channel then pcall(vim.fn.jobstop, job.channel) end
    core.jobs[id] = nil
  end
  for _, channel in ipairs(processes) do pcall(vim.fn.jobstop, channel) end
  if #failures == 0 or vim.env.TASKBAY_TEST_KEEP ~= "1" then
    vim.fn.delete(T.temp, "rf")
  else
    io.stderr:write("kept test files in " .. T.temp .. "\n")
  end
  if #failures > 0 then
    io.stderr:write(("%s: %d case(s) failed: %s\n"):format(T.name, #failures, table.concat(failures, ", ")))
    vim.cmd("cquit 1")
  end
  print(summary)
  vim.cmd("qa!")
end

return T
end

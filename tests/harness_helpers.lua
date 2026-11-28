-- The end-to-end harness checks its own helpers. Run: timeout 120 nvim --headless -u NONE -i NONE -l tests/harness_helpers.lua
local H = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/harness.lua")({ name = "taskbay-harness" })
local lua, wait_for = H.lua, H.wait_for
local function fails(fn, text)
  local ok, err = pcall(fn)
  assert(not ok and tostring(err):find(text, 1, true), "Expected an error containing " .. text .. ", got " .. tostring(err))
end
vim.fn.writefile({ "before" }, H.repo .. "/file.txt")
H.sh({ "git", "add", "file.txt" })
H.sh({ "git", "commit", "-q", "-m", "Add file.txt" })
vim.fn.writefile({ "after" }, H.repo .. "/file.txt")

H.run("taskbay harness: invariants, layouts, repositories, diff and fields drivers, gh stand-in", function()
  local other = H.create_repository("other", { ["x.txt"] = { "x" } })
  assert(H.sh({ "git", "ls-files" }, other) == "x.txt")
  H.boot({ cwd = other })
  assert(lua("return vim.fn.getcwd()") == other, "boot({ cwd }) starts the editor there")
  H.boot()
  H.invariants()

  -- Errors shown to the user break the invariants, unless allowed.
  lua("vim.notify('E999: injected')")
  fails(H.invariants, "E999: injected")
  lua("vim.api.nvim_echo({ { 'E998: echoed' } }, true, {})")
  fails(H.invariants, "E998: echoed")
  H.allow("E997")
  lua("vim.notify('E997: expected')")
  H.invariants()

  -- A task with a changed file, its agent shown in the task tab.
  lua([[
    local root = ...
    local core = require("taskbay.core")
    _G.ws = { id = "harness", path = root, common = root .. "/.git", branch = "main", base_ref = "main",
      source = "github", repo = "test/repo", host = "github.com", number = 42, title = "Harness task" }
    core.workspaces.harness = ws
    core.open(ws)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_call(buf, function() _G.ws_job = vim.fn.jobstart({ "sleep", "30" }, { term = true }) end)
    core.jobs.harness = { buf = buf, channel = ws_job, activity = "idle" }
    core.show(ws)
    vim.cmd.stopinsert()
  ]], H.repo)
  H.invariants()
  lua("vim.wo[vim.fn.win_findbuf(require('taskbay.core').jobs.harness.buf)[1]].winfixbuf = false")
  fails(H.invariants, "is not pinned")
  lua("vim.wo[vim.fn.win_findbuf(require('taskbay.core').jobs.harness.buf)[1]].winfixbuf = true")

  H.layout("agent_only")
  assert(lua([[return #vim.tbl_filter(function(win) return vim.api.nvim_win_get_config(win).relative == "" end,
    vim.api.nvim_tabpage_list_wins(0))]]) == 1, "agent_only leaves one window")
  lua("vim.cmd.tabnew()")
  lua("vim.cmd.tabprevious()")
  H.layout("single_tab")
  assert(lua("return #vim.api.nvim_list_tabpages()") == 1, "single_tab leaves one tab")
  fails(function() H.layout("nonsense") end, "Unknown layout nonsense")
  lua("vim.cmd('botright vsplit | enew')")

  H.diff(42, "file.txt")
  wait_for("H.diff opens the picked file", "return vim.api.nvim_buf_get_name(0):sub(-8) == 'file.txt'")

  lua([[
    local root = ...
    local core, tasks = require("taskbay.core"), require("taskbay.store")
    local repo = { root = root, common = root .. "/.git", source = "local", repo = "project", host = "local" }
    local task = tasks.create(repo, "Fields task")
    core.workspaces.fields = vim.tbl_extend("force", task, {
      id = "fields", path = root, branch = "main", base_ref = "main", title = "Fields task", task_root = root,
    })
    _G.fields_number = task.number
  ]], H.repo)
  H.fields(lua("return fields_number"))
  lua("require('taskbay.core').workspaces.fields = nil")

  local stub = H.gh({ { number = 7, title = "Seeded", body = "one\r\ntwo", state = "OPEN" } })
  local out = H.sh({ H.temp .. "/bin/gh", "issue", "view", "7", "--repo", "octo/project", "--json", "title,body" })
  assert(vim.json.decode(out).body == "one\r\ntwo" and stub.issue(7).title == "Seeded")
  local views = stub.calls("view")
  assert(#views >= 1 and views[#views][3] == "7" and stub.calls()[1][1] == "issue", vim.inspect(stub.calls()))

  lua([[
    local core = require("taskbay.core")
    vim.fn.jobstop(ws_job)
    core.jobs.harness, core.workspaces.harness = nil, nil
  ]])
end)

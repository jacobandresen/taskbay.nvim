-- #2: opening a changed file from the diff picker must take its name literally: no shell
-- command from backticks, no %/# file-name expansion, no $VAR expansion.
local H = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h") .. "/harness.lua")({ name = "taskbay-regression-2" })
local lua, wait_for = H.lua, H.wait_for
local names = { "`touch PWNED`.txt", "a#b.txt", "c%d.txt", "g$HOME.txt", "sp ace.txt" }
for _, name in ipairs(names) do vim.fn.writefile({ "x" }, H.repo .. "/" .. name) end

H.run("regression #2: the diff picker opens hostile file names literally", function()
  H.boot()
  lua([[
    local root = ...
    local core = require("taskbay.core")
    local workspace = { id = "regression-2", path = root, common = root .. "/.git", branch = "main", base_ref = "main",
      source = "github", repo = "test/repo", host = "github.com", number = 42, title = "Hostile names" }
    core.workspaces[workspace.id] = workspace
    core.open(workspace)
    -- Give % and # values, so expansion would show.
    vim.cmd.edit(vim.fn.fnameescape(root .. "/README.md"))
    vim.cmd.edit(vim.fn.fnameescape(root .. "/app.py"))
  ]], H.repo)
  for _, name in ipairs(names) do
    H.diff(42, name)
    wait_for("The diff picker must open " .. name, "return vim.api.nvim_buf_get_name(0) == ...", 5000, H.repo .. "/" .. name)
  end
  -- The task tab's working directory is literal too: worktrees live where the repository is.
  local odd = H.temp .. "/c#-%-project"
  vim.fn.mkdir(odd, "p")
  assert(lua([[
    local path = ...
    local core = require("taskbay.core")
    core.workspaces.odd = { id = "odd", path = path, branch = "main", base_ref = "main", source = "github",
      repo = "test/repo", host = "github.com", number = 43, title = "Odd directory" }
    core.open(core.workspaces.odd)
    return vim.fn.getcwd()
  ]], odd) == odd, "The task tab's directory must be the worktree's literal path")
  assert(not vim.uv.fs_stat(H.repo .. "/PWNED") and not vim.uv.fs_stat(H.temp .. "/PWNED"),
    "A backtick file name must not run a shell command")
end)

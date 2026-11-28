-- #15: a newly opened panel never shows the new tasks of the repository it was last opened in.
local T = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h") .. "/lib.lua")({ name = "regression-15" })
local tasks, ui = require("taskbay.store"), require("taskbay.ui")
local a, b = T.create_repository("alpha"), T.create_repository("beta")
local root = a.root
_G.LazyVim = { root = function() return root end }
local function text() return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n") end

T.case("switching repositories", function()
  tasks.create(a, "Alpha only")
  vim.cmd.edit(vim.fn.fnameescape(a.root .. "/README.md"))
  ui.dashboard()
  assert(vim.wait(3000, function() return text():find("Alpha only", 1, true) ~= nil end, 10), text())
  vim.cmd.close()
  root = b.root
  vim.cmd.edit(vim.fn.fnameescape(b.root .. "/README.md"))
  ui.dashboard()
  assert(not text():find("Alpha only", 1, true), "The first draw shows the other repository's task:\n" .. text())
  vim.wait(500)
  assert(not text():find("Alpha only", 1, true), "The reloaded panel shows the other repository's task:\n" .. text())
  vim.cmd.close()
end)

T.done("regression #15: the panel shows only the current repository's tasks")

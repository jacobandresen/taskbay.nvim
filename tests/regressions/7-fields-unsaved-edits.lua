-- #7: switching away from the Fields tab and back keeps its unsaved edits.
local T = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h") .. "/lib.lua")({ name = "regression-7" })
local core, tasks = require("taskbay.core"), require("taskbay.store")
local repository = T.create_repository("repo")
_G.LazyVim = { root = function() return repository.root end }
local function prepare(title)
  local task = tasks.create(repository, title)
  return T.await(function() return core.prepare(repository, task, "main", true) end)
end

local fields = require("taskbay.fields")

T.case("unsaved Fields edits survive reopening", function()
  local task = tasks.create(repository, "Fields task")
  local target = vim.tbl_extend("force", task, { task_root = repository.root, path = repository.root })
  local function open()
    fields.open(target)
    assert(vim.wait(3000, function() return vim.api.nvim_buf_get_name(0):find("task://fields/", 1, true) ~= nil end, 10))
  end
  open()
  local buf = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local row
  for index, line in ipairs(lines) do if line:match("^labels:") then row = index end end
  assert(row, "Fields must show a labels line: " .. vim.inspect(lines))
  vim.api.nvim_buf_set_lines(buf, row - 1, row, false, { "labels: bug" })
  vim.cmd.enew()
  open()
  assert(vim.api.nvim_get_current_buf() == buf)
  assert(vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] == "labels: bug", "The edit must be kept")
  assert(vim.bo[buf].modified, "The buffer must still be marked modified")
end)

T.done("regression #7: unsaved Fields edits are kept")

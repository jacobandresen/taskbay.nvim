-- #8: saving Fields reads every line, also when the header is gone and labels is line 1.
local T = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h") .. "/lib.lua")({ name = "regression-8" })
local core, tasks = require("taskbay.core"), require("taskbay.store")
local repository = T.create_repository("repo")
_G.LazyVim = { root = function() return repository.root end }
local function prepare(title)
  local task = tasks.create(repository, title)
  return T.await(function() return core.prepare(repository, task, "main", true) end)
end

local fields = require("taskbay.fields")

T.case("labels on line 1 are saved", function()
  local task = tasks.create(repository, "Fields header")
  local target = vim.tbl_extend("force", task, { task_root = repository.root, path = repository.root })
  fields.open(target)
  assert(vim.wait(3000, function() return vim.api.nvim_buf_get_name(0):find("task://fields/", 1, true) ~= nil end, 10))
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local row
  for index, line in ipairs(lines) do if line:match("^labels:") then row = index break end end
  vim.api.nvim_buf_set_lines(0, 0, row, false, { "labels: bug" })
  vim.cmd("silent write")
  assert(vim.wait(3000, function() return T.notified("Saved fields") end, 10), table.concat(T.messages, "\n"))
  assert(vim.deep_equal(tasks.get_meta(target).labels, { "bug" }), vim.inspect(tasks.get_meta(target)))
end)

T.done("regression #8: Fields saves its first line")

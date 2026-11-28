-- #13: one malformed task file is reported and skipped; the other tasks stay listed.
local T = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h") .. "/lib.lua")({ name = "regression-13" })
local core, tasks = require("taskbay.core"), require("taskbay.store")

for _, layout in ipairs({ "no_blank_line", "orphan_sidecar" }) do
  T.case(layout, function()
    local repository = T.create_repository(layout)
    T.write_tasks(repository, layout)
    local listed, problems = tasks.list(repository)
    assert(#listed == 1 and listed[1].title == "A", vim.inspect(listed))
    assert(#problems == 1, vim.inspect(problems))
  end)
end

T.case("the panel shows the valid task and reports the broken one", function()
  local repository = T.create_repository("panel")
  T.write_tasks(repository, "no_blank_line")
  _G.LazyVim = { root = function() return repository.root end }
  vim.cmd.edit(vim.fn.fnameescape(repository.root .. "/README.md"))
  require("taskbay.ui").dashboard()
  assert(vim.wait(3000, function() return T.notified("Skipped malformed task files") end, 10), table.concat(T.messages, "\n"))
  assert(T.notified("002-b.md"), "The message must name the broken file")
  assert(vim.wait(3000, function()
    return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n"):find("#1 A", 1, true) ~= nil
  end, 10), "The panel must list the valid task: " .. table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n"))
  vim.cmd.close()
end)

T.done("regression #13: malformed task files are reported, not hiding the rest")

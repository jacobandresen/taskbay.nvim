-- #3: a new local task gets the numeric maximum ID plus one, whatever the directory order.
local T = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h") .. "/lib.lua")({ name = "regression-3" })
local tasks = require("taskbay.store")

-- List directories in ascending name order, like many file systems do: "1000-b.md" comes before
-- "999-a.md", so the last entry is not the highest ID.
local dir = vim.fs.dir
vim.fs.dir = function(path, opts)
  local entries = {}
  for name, kind in dir(path, opts) do entries[#entries + 1] = { name, kind } end
  table.sort(entries, function(a, b) return a[1] < b[1] end)
  local index = 0
  return function()
    index = index + 1
    if entries[index] then return entries[index][1], entries[index][2] end
  end
end

for _, case in ipairs({ { "unpadded", 11 }, { "unordered", 1001 } }) do
  T.case(case[1] .. " IDs", function()
    local repository = T.create_repository(case[1])
    T.write_tasks(repository, case[1])
    local created = tasks.create(repository, "New")
    assert(created.number == case[2], "Expected ID " .. case[2] .. ", got " .. created.number)
    local listed, problems = tasks.list(repository)
    assert(#listed == 3 and #(problems or {}) == 0, vim.inspect(problems))
  end)
end

T.done("regression #3: task IDs follow the numeric maximum")

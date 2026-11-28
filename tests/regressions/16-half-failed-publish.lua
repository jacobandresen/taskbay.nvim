-- #16: when publishing changes the text and the state, and only the state change fails, a retry
-- publishes the remaining state change instead of reporting "Issue changed".
local T = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h") .. "/lib.lua")({ name = "regression-16", settings = { remote_enabled = true } })
local core, editor, fields = require("taskbay.core"), require("taskbay.editor"), require("taskbay.fields")
local remote = { number = 42, title = "Original", body = "Body", url = "https://github.com/test/repo/issues/42",
  state = "OPEN", labels = {}, assignees = {}, comments = {} }
local fail_close = true
core.run = function(argv, _, _, stdin)
  assert(argv[1] == "gh", vim.inspect(argv))
  if argv[3] == "view" then return { code = 0, stdout = vim.json.encode(remote) } end
  if argv[3] == "edit" then
    for index, arg in ipairs(argv) do if arg == "--title" then remote.title = argv[index + 1] end end
    remote.body = stdin or remote.body
    return { code = 0, stdout = "" }
  end
  if argv[3] == "close" then
    if fail_close then error("gh issue close failed", 0) end
    remote.state = "CLOSED"
    return { code = 0, stdout = "" }
  end
  error("Unexpected gh call: " .. vim.inspect(argv))
end
local target = { id = "draft", source = "github", host = "github.com", repo = "test/repo", number = 42, path = T.temp }
core.workspaces[target.id] = target
vim.t.taskbay_workspace = target.id

T.case("retry after a failed state change", function()
  editor.open(target)
  assert(vim.wait(3000, function() return vim.b.taskbay_task ~= nil end, 10), table.concat(T.messages, "\n"))
  local draft = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(draft, 0, 1, false, { "# New title" })
  fields.open(target)
  assert(vim.wait(3000, function() return vim.api.nvim_buf_get_name(0):find("task://fields/", 1, true) ~= nil end, 10))
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  for index, line in ipairs(lines) do
    if line:match("^state:") then vim.api.nvim_buf_set_lines(0, index - 1, index, false, { "state: closed" }) end
  end
  vim.cmd("silent write")
  assert(vim.wait(3000, function() return T.notified("Saved fields") end, 10), table.concat(T.messages, "\n"))
  vim.api.nvim_set_current_buf(draft)
  T.choose({ { answer = "Publish title, body and fields" } })
  editor.publish(draft)
  assert(vim.wait(3000, function() return T.notified("gh issue close failed") end, 10), table.concat(T.messages, "\n"))
  assert(remote.title == "New title" and remote.state == "OPEN")
  fail_close = false
  T.choose({ { answer = "Publish title, body and fields" } })
  editor.publish(draft)
  assert(vim.wait(3000, function() return T.notified("Published") end, 10), table.concat(T.messages, "\n"))
  assert(remote.state == "CLOSED", "The retry must close the issue")
end)

T.done("regression #16: a retry publishes what a failed publish left out")

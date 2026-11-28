-- #12: text containing ESC[201~ is pasted whole: the end-of-paste marker inside it is removed.
local T = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h") .. "/lib.lua")({ name = "regression-12" })
local core, tasks = require("taskbay.core"), require("taskbay.store")
local repository = T.create_repository("repo")
_G.LazyVim = { root = function() return repository.root end }
local function prepare(title)
  local task = tasks.create(repository, title)
  return T.await(function() return core.prepare(repository, task, "main", true) end)
end

T.case("one end-of-paste marker, at the end", function()
  local workspace = prepare("Paste")
  local job = T.start(workspace)
  core.paste(workspace, "first\27[201~\rsecond")
  vim.api.nvim_chan_send(job.channel, "\n") -- the stand-in reads whole lines
  assert(vim.wait(3000, function() return T.received(workspace):find("second", 1, true) ~= nil end, 10))
  local received = T.received(workspace)
  local _, markers = received:gsub("\27%[201~", "")
  assert(markers == 1, "Expected one end-of-paste marker, got " .. markers .. ": " .. vim.inspect(received))
  assert(received:find("second", 1, true) < received:find("\27[201~", 1, true), vim.inspect(received))
  assert(T.await(function() return core.stop_wait(workspace, job) end))
end)

T.done("regression #12: pastes keep their end-of-paste marker at the end")

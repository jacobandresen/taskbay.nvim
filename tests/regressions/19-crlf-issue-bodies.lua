-- #19: GitHub issue bodies with CRLF line endings are read with plain newlines.
local T = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h") .. "/lib.lua")({ name = "regression-19", settings = { remote_enabled = true } })
local core = require("taskbay.core")
core.run = function()
  return { code = 0, stdout = vim.json.encode({ number = 7, title = "CRLF\r", body = "one\r\ntwo\r\n", state = "OPEN" }) }
end

T.case("the body has no carriage returns", function()
  local issue = T.await(function()
    return require("taskbay.remotes.github").get({ host = "github.com", repo = "test/repo", number = 7, path = T.temp })
  end)
  assert(issue.body == "one\ntwo\n" and issue.title == "CRLF", vim.inspect(issue))
  assert(issue.raw.body == "one\r\ntwo\r\n", "The raw issue is kept verbatim")
end)

T.done("regression #19: CRLF issue bodies are read with plain newlines")

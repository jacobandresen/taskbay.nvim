-- Inputs that are known to break editors, terminals and shell tools. Tests loop over them.
return {
  -- File names with characters Neovim's command line or the shell may interpret.
  names = {
    "`touch PWNED`.txt", "a#b.txt", "c%d.txt", "g$HOME.txt", "sp ace.txt", "new\nline.txt", "ünï.txt", "-dash.txt",
  },
  -- File contents that are hard to pass through a terminal or a line-based parser.
  contents = {
    end_of_paste = { "before", "\27[201~\rafter" },
    crlf = { "one\r", "two\r" },
    long_line = { string.rep("x", 100000) },
    empty = {},
  },
  -- Broken .tasks/ directories: file name -> lines. T.write_tasks(repository, name) writes one.
  tasks = {
    unordered = {
      ["999-a.md"] = { "# A", "", "Body" },
      ["1000-b.md"] = { "# B", "", "Body" },
    },
    unpadded = {
      ["009-a.md"] = { "# A", "", "Body" },
      ["10-b.md"] = { "# B", "", "Body" },
    },
    orphan_sidecar = {
      ["001-a.md"] = { "# A", "", "Body" },
      ["003.json"] = { "{}" },
    },
    no_blank_line = {
      ["001-a.md"] = { "# A", "", "Body" },
      ["002-b.md"] = { "# B", "Body right after the title" },
    },
    bad_json = {
      ["001-a.md"] = { "# A", "", "Body" },
      ["001.json"] = { '{"labels": [' },
    },
  },
}

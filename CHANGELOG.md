# Changelog

All notable changes to taskbay.nvim. Versions follow [Semantic Versioning](https://semver.org).

## [0.1.4] - 2026-11-28

### Fixed

- Saving the Fields tab reads every line. Before, its first line was skipped, so labels on line 1 were dropped ([#8](https://github.com/jacobandresen/taskbay.nvim/issues/8)).
- Sent text containing an end-of-paste sequence (`ESC[201~`) is pasted whole. Before, the paste ended early and the rest was typed into the agent as keys ([#12](https://github.com/jacobandresen/taskbay.nvim/issues/12)).
- A newly opened panel shows only the current repository's new tasks. Before, it briefly showed, and let keys act on, the previous repository's ([#15](https://github.com/jacobandresen/taskbay.nvim/issues/15)).
- When publishing a GitHub draft changes the text and the state and only the state change fails, a retry publishes the state change. Before, every retry was blocked with "Issue changed on GitHub" ([#16](https://github.com/jacobandresen/taskbay.nvim/issues/16)).
- A lock file (`owner.json`) is written in one step, and an empty or corrupt one left by a crash can be recovered. Before, the task could not start until the file was deleted by hand ([#18](https://github.com/jacobandresen/taskbay.nvim/issues/18)).
- GitHub issues with CRLF line endings are read with plain newlines. Before, task files showed `^M` on every body line ([#19](https://github.com/jacobandresen/taskbay.nvim/issues/19)).

## [0.1.3] - 2026-11-28

### Fixed

- The pi extension's subagent guard allows only the fields a single foreground call needs (agent, task, async, model, cwd, worktree). Before, workflow scripts, scheduled runs, management actions and `options` passed it ([#11](https://github.com/jacobandresen/taskbay.nvim/issues/11)).
- New local tasks get the highest existing ID plus one, whatever order the directory lists files in. Before, IDs could repeat and every listing then failed ([#3](https://github.com/jacobandresen/taskbay.nvim/issues/3)).
- The diff picker opens files beside the agent's terminal when it is the only window in the task tab, instead of failing with E1513 ([#4](https://github.com/jacobandresen/taskbay.nvim/issues/4)).
- A restart that cannot start the agent keeps the task's saved conversation and finished mark ([#6](https://github.com/jacobandresen/taskbay.nvim/issues/6)).
- Switching away from the Fields tab and back keeps its unsaved edits ([#7](https://github.com/jacobandresen/taskbay.nvim/issues/7)).
- Finish, delete and restart refuse a task whose agent runs in another Neovim ([#9](https://github.com/jacobandresen/taskbay.nvim/issues/9)).
- A malformed task file is skipped and reported; the panel still lists the other tasks ([#13](https://github.com/jacobandresen/taskbay.nvim/issues/13)).
- Deleting a task works when its tab is the only tab, and a refused delete no longer stops the agent first ([#17](https://github.com/jacobandresen/taskbay.nvim/issues/17)).
- F6 in a standalone agent terminal hides it, also when Neovim's working directory is outside the repository, instead of starting a second agent ([#25](https://github.com/jacobandresen/taskbay.nvim/issues/25), [#14](https://github.com/jacobandresen/taskbay.nvim/issues/14)).

## [0.1.2] - 2026-11-28

### Fixed

- Opening a changed file from the diff picker takes its name literally. Before, backticks in a file name ran a shell command, and `%`, `#` and `$VAR` were expanded, so the wrong file opened ([#2](https://github.com/jacobandresen/taskbay.nvim/issues/2)).
- A task tab opens in its worktree even when the repository's path contains `%` or `#` (such as `c#-project`). Before, opening it failed with E499.
- Errors raised after taskbay waited, for example after stopping an agent, are shown again. Before, deleting, finishing or restarting a task could stop halfway without a message ([#5](https://github.com/jacobandresen/taskbay.nvim/issues/5)).
- Finishing a task commits every change in its worktree, including files written while the finish dialog was open or before its agent stopped. Before, those changes were left out of the merge and the task was still marked finished ([#10](https://github.com/jacobandresen/taskbay.nvim/issues/10)).

## [0.1.1] - 2026-11-28

### Fixed

- Choosing a file in the Snacks explorer or a picker no longer replaces the agent terminal in a task tab ([#1](https://github.com/jacobandresen/taskbay.nvim/issues/1)). Files now open in the task window, and the agent window is pinned to its terminal (`winfixbuf`): `:edit` there fails with E1513 instead of hiding the agent.

## [0.1.0] - 2026-11-26

First release.

[0.1.4]: https://github.com/jacobandresen/taskbay.nvim/compare/v0.1.3...v0.1.4
[0.1.3]: https://github.com/jacobandresen/taskbay.nvim/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/jacobandresen/taskbay.nvim/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/jacobandresen/taskbay.nvim/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/jacobandresen/taskbay.nvim/releases/tag/v0.1.0

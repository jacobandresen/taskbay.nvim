# Changelog

All notable changes to taskbay.nvim. Versions follow [Semantic Versioning](https://semver.org).

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

[0.1.2]: https://github.com/jacobandresen/taskbay.nvim/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/jacobandresen/taskbay.nvim/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/jacobandresen/taskbay.nvim/releases/tag/v0.1.0

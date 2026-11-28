# Changelog

All notable changes to taskbay.nvim. Versions follow [Semantic Versioning](https://semver.org).

## [0.1.1] - 2026-11-28

### Fixed

- Choosing a file in the Snacks explorer or a picker no longer replaces the agent terminal in a task tab ([#1](https://github.com/jacobandresen/taskbay.nvim/issues/1)). Files now open in the task window, and the agent window is pinned to its terminal (`winfixbuf`): `:edit` there fails with E1513 instead of hiding the agent.

## [0.1.0] - 2026-11-26

First release.

[0.1.1]: https://github.com/jacobandresen/taskbay.nvim/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/jacobandresen/taskbay.nvim/releases/tag/v0.1.0

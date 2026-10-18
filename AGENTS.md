# Agent guidelines

Conventions for coding agents (and humans) working in this repo.

## Code style

- **No default values on boolean parameters.** Declare flags as
  `required bool clearNote`, not `bool clearNote = false`, so every call
  site states its intent explicitly (e.g. `ActivityEvent.copyWith`).

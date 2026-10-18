# Agent guidelines

Conventions for coding agents (and humans) working in this repo.

## Code style

- **No default values on boolean parameters.** Declare flags as
  `required bool clearNote`, not `bool clearNote = false`, so every call
  site states its intent explicitly (e.g. `ActivityEvent.copyWith`).

## Pull requests

- **Stacked PRs must end up targeting `main`.** When a PR is based on
  another PR's branch, retarget it to `main` (`gh pr edit <n> --base main`)
  as soon as the PR below it merges, before merging it. Otherwise GitHub
  merges it into the lower branch, which has already landed, so its code
  never reaches `main` and its `Fixes #N` issues stay open (this happened
  with #23–#25; recovered in #27).
- After merging, check the change is actually on `main`, e.g.
  `git merge-base --is-ancestor <commit> origin/main`.

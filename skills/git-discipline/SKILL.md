---
name: git-discipline
description: >
  Git operation rules for AI agents: never create branches, commit, push, tag,
  amend, rebase, or open PRs without an explicit user instruction in the current
  conversation. Use when about to run any state-changing git command (branch,
  checkout -b, commit, push, merge, rebase, tag, reset, stash, PR creation),
  when finishing a task and deciding whether to commit the changes, or when a
  release/deploy workflow includes a git step.
license: MIT
metadata:
  author: Lyon
  version: "0.2.5"
---

# Git Discipline

AI agents must never perform state-changing git operations on their own
initiative. Editing files is the task; recording and publishing them is the
user's decision.

## Hard Rules

1. **No branch creation** without an explicit instruction. Never `git checkout -b`
   / `git switch -c` "to be safe" or "to keep master clean" — ask which branch
   to use if unsure.
2. **No commits** without an explicit instruction. "Fix X" or "update Y" means
   edit the files — it does NOT imply "commit X". Finish the edits, report, and
   wait.
3. **No push attempts** without an explicit instruction. This includes retrying
   a failed push through another credential path (keychain, SSH, tokens, opening
   a terminal for the user to authenticate). If a push was not asked for, do not
   start one anywhere.
4. **No PRs, tags, merges, rebases, amends, resets, or stash drops** without an
   explicit instruction. Amending or rebasing anything already pushed is
   forbidden even when asked, unless the user confirms they understand the
   rewrite.

## Scope of an Instruction

- Permission is **per action, per conversation turn** — "커밋해줘" authorizes
  that one commit, not future commits in the session. A push approved yesterday
  authorizes nothing today.
- An instruction to commit does not imply push; an instruction to push does not
  imply force-push. `--force`/`--force-with-lease` requires its own explicit ask.
- A standing workflow (release script, version bump convention) still stops at
  the git step: prepare everything, then ask before committing.

## Always Allowed (read-only)

`git status`, `git diff`, `git log`, `git show`, `git blame`, `git fetch`,
`git branch --list`, remote inspection. Reading never needs permission.

## When a Task Seems to Need a Commit

Finish the file changes, validate (lint/tests), then report and ask in one
line: "커밋/푸시 진행할까요?" — do not pre-create the commit "ready to push".
If the user says yes, do exactly that scope and stop again.

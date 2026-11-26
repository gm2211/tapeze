# Agent Instructions

## Non-Interactive Shell Commands

**ALWAYS use non-interactive flags** with file operations to avoid hanging on confirmation prompts.

Shell commands like `cp`, `mv`, and `rm` may be aliased to include `-i` (interactive) mode on some systems, causing the agent to hang indefinitely waiting for y/n input.

**Use these forms instead:**
```bash
# Force overwrite without prompting
cp -f source dest           # NOT: cp source dest
mv -f source dest           # NOT: mv source dest
rm -f file                  # NOT: rm file

# For recursive operations
rm -rf directory            # NOT: rm -r directory
cp -rf source dest          # NOT: cp -r source dest
```

**Other commands that may prompt:**
- `scp` - use `-o BatchMode=yes` for non-interactive
- `ssh` - use `-o BatchMode=yes` to fail instead of prompting
- `apt-get` - use `-y` flag
- `brew` - use `HOMEBREW_NO_AUTO_UPDATE=1` env var

## Issue tracking

Tasks are GitHub Issues, managed with the `gh` CLI:

```bash
gh issue list                                       # Find open work
gh issue create --title "..." --body "..."          # File a task
gh issue close <n> --comment "Completed in #<pr>"   # Complete work
```

For follow-up work discovered along the way, file a new issue and reference the parent issue number (for example "Follow-up to #12") in the body.

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create GitHub Issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds

## Build & Test

_Add your build and test commands here_

```bash
# Example:
# npm install
# npm test
```

## Shipping to TestFlight

Run `scripts/upload-testflight.sh` on the Mac. Never archive with
`CODE_SIGNING_ALLOWED=NO`: the export still succeeds, but the signed app and
keyboard lose the `group.com.gm2211.tapeze` entitlement, so the keyboard can't
read any setting from the app (build 47 shipped like this). The script now
refuses to upload an IPA whose bundles lack that entitlement.

## Architecture Overview

_Add a brief overview of your project architecture_

## Conventions & Patterns

_Add your project-specific conventions here_

## Remote Control on the Mac

The Claude desktop app serves at most six folders for Remote Control, and
`~/projects/tapeze` is often not one of them. A Remote Control request that
names an unserved folder posts a card that fails with "Couldn't record your
choice", however often it is stopped and restarted. Instead, call
`list_devices`, pick any folder on the same Mac whose state is `served`, pass
its `environment_id` to `start_remote_control`, and tell the session to leave
that folder alone and work in `/Users/gmecocci/projects/tapeze` (in a git
worktree, so the user's checkout stays untouched).

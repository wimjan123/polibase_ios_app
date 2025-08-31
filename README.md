# polibase_ios_app (Local Workspace)

This workspace contains planning artifacts for the Polibase iOS app.

To create a GitHub repo named `polibase_ios_app` and push this workspace, run the helper script below. It requires either a logged-in `gh` CLI or the environment variables `GITHUB_TOKEN` and `GITHUB_OWNER`.

Run with gh (interactive):

```bash
./scripts/create_and_push_repo.sh
```

Run non-interactively with token:

```bash
export GITHUB_OWNER=your-username-or-org
export GITHUB_TOKEN=ghp_xxx...
./scripts/create_and_push_repo.sh
```

After the script completes, update `.copilot-tracking/changes/20250831-ios-political-transcript-platform-changes.md` with the remote URL and commit references.

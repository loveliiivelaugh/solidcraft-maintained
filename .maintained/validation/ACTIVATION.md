# Controlled validation activation

The maintained fork's imported workflows are untrusted automation. All their jobs are explicitly gated off with `if: ${{ false }}` in this control commit. Their original conditions remain in Git history and require deliberate review before restoration. The only executable workflow is maintained-validation.yml, with manual dispatch, no Actions-token permissions and no third-party actions.

GitHub requires a manual-dispatch workflow to exist on the default branch. This control change is separate from the unmerged security-source repairs. Before enabling Actions, verify the default-branch tree has every imported job disabled, then block all third-party/GitHub-owned action uses and verify token defaults are read-only. After indexing, also disable every imported workflow through the GitHub API. Dispatch only maintained-validation.yml with the reviewed full candidate SHA; do not enable deployment workflows or automatic merges. Disable repository Actions after validation ends.

A blocked/failed/partially completed run is not a passing validation. Preserve step conclusions and logs. No private secrets, local files, production permissions or private-network access belong in the job.

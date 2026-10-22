# Disposable SolidCraft validation

Destination: the existing loveliiivelaugh/solidcraft-maintained fork. No new repository. The trusted harness lives in .maintained/validation, and every imported workflow job must be disabled before Actions can be enabled for a manual run. It contains no secrets or private source. Standard GitHub-hosted Ubuntu runners validate only public pinned source; no local files, credentials or private networking are attached. No code is deployed or merged.

The manual-only workflow uses `permissions: {}`. Source execution runs as an unprivileged UID in a systemd sandbox with a private network, protected runner home, no capabilities, a sanitized environment, resource/time limits and root-owned trusted toolchains/harness. Trusted Cargo prefetches dependencies before network-disabled builds. There are no shared caches. Workflow commands are disabled around untrusted test output. Every source/build/test result is linked back to Maintained.

Planned gates: boundary self-test; cgmath matrix regression; Miri aliasing regression; SolidCraft workspace build and tests; full `cargo xtask ci`. Linux results cannot establish Windows/macOS, signing, interactive GPU or arbitrary hostile-document safety. Full CI may expose missing platform tools or unrelated baseline failures; those must remain visible.

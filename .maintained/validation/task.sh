#!/usr/bin/env bash
set -euo pipefail
case "$1" in
 prefetch)
   cargo +1.95.0 fetch --locked
   cargo +1.95.0 generate-lockfile --manifest-path vendor/cgmath/Cargo.toml
   cargo +1.95.0 fetch --manifest-path vendor/cgmath/Cargo.toml --locked
   cargo +nightly miri setup
   ;;
 isolation)
   python3 - <<'PY'
import os,socket,pathlib
assert os.getuid()!=0
assert not any(k in os.environ for k in ['GITHUB_TOKEN','GH_TOKEN','ACTIONS_RUNTIME_TOKEN','AWS_ACCESS_KEY_ID','SSH_AUTH_SOCK'])
assert not pathlib.Path('/home/runner').exists() or not os.access('/home/runner',os.R_OK)
try:
    socket.create_connection(('1.1.1.1',443),timeout=2)
except OSError:
    print('PASS: outbound networking denied')
else:
    raise SystemExit('FAIL: network egress available')
print('PASS: unprivileged UID, sanitized environment and protected runner home')
PY
   ;;
 matrix)
   cargo +1.95.0 test --manifest-path vendor/cgmath/Cargo.toml --locked --offline --test matrix
   ;;
 miri)
   cargo +nightly miri test --manifest-path vendor/cgmath/Cargo.toml --locked --offline --test matrix swapping_equal_and_distinct_matrix_indices
   ;;
 build)
   cargo +1.95.0 build --workspace --profile ci --locked --offline
   ;;
 test)
   cargo +1.95.0 test --workspace --profile ci --locked --offline -- --test-threads=3
   ;;
 ci)
   xvfb-run -a cargo +1.95.0 xtask ci
   ;;
 *) echo 'Unknown phase' >&2;exit 2;;
esac

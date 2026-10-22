#!/usr/bin/env bash
set -euo pipefail
case "$1" in
 prefetch)
   cargo +1.95.0 fetch --locked
   if [[ -d vendor/cgmath ]]; then
     cargo +1.95.0 generate-lockfile --manifest-path vendor/cgmath/Cargo.toml
     cargo +1.95.0 fetch --manifest-path vendor/cgmath/Cargo.toml --locked
     cargo +nightly miri setup
   fi
   ;;
 isolation)
   python3 - <<'PY'
import os,socket,pathlib
assert os.getuid()!=0
assert not any(k in os.environ for k in ['GITHUB_TOKEN','GH_TOKEN','ACTIONS_RUNTIME_TOKEN','AWS_ACCESS_KEY_ID','SSH_AUTH_SOCK'])
try:
    list(pathlib.Path('/home/runner').iterdir())
except (PermissionError, FileNotFoundError):
    print('PASS: runner home inaccessible')
else:
    raise SystemExit('FAIL: runner home readable')
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
 readiness-fast)
   cargo +1.95.0 fmt --all -- --check
   cargo +1.95.0 clippy --workspace --all-targets --profile ci --locked --offline -- -D warnings
   cargo +1.95.0 test -p solidcraft-geom --lib --profile ci --locked --offline tests::a_long_helical_tangent_chain_is_found_quickly -- --exact --test-threads=1
   cargo +1.95.0 xtask licences
   python3 - <<'PYNOTICE'
import base64,hashlib,pathlib
p=pathlib.Path('THIRD-PARTY-LICENSES.txt').read_bytes()
print('MAINTAINED_NOTICE_SHA256='+hashlib.sha256(p).hexdigest())
print('MAINTAINED_NOTICE_BASE64='+base64.b64encode(p).decode())
PYNOTICE
   ;;
 static)
   cargo +1.95.0 fmt --all -- --check
   for gate in assets icons licences lists layers ui-containers; do cargo +1.95.0 xtask "$gate" --check; done
   cargo +1.95.0 clippy --workspace --all-targets --profile ci --locked --offline -- -D warnings
   ;;
 compile-tests)
   cargo +1.95.0 test --workspace --profile ci --locked --offline --no-run
   ;;
 bounded-tests)
   xvfb-run -a cargo +1.95.0 xtask test --locked -- --test-threads=2
   ;;
 wasm)
   cargo +1.95.0 xtask wasm
   ;;
 browser)
   cargo +1.95.0 xtask web-offline-test
   ;;
 desktop-smoke)
   cargo +1.95.0 build --profile ci --locked --offline -p solidcraft -p solidcraft-cli
   target/ci/solidcraft --help
   target/ci/solidcraft-cli --help
   ;;
 tests)
   xvfb-run -a cargo +1.95.0 xtask test --locked -- --test-threads=3
   ;;
 baseline-model-cache)
   cargo +1.95.0 test -p solidcraft-cli --test model_cache --profile ci --locked --offline -- --test-threads=3
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

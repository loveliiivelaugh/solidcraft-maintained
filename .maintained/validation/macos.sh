#!/usr/bin/env bash
set -euo pipefail
phase=$1
root=/var/lib/solidcraft
case "$phase" in
 provision)
   sudo mkdir -p "$root"/{home,cargo,tmp,runtime} /opt/maintained-cargo/bin /opt/maintained-harness
   rustup_bin=$(command -v rustup)
   sudo env RUSTUP_HOME=/opt/maintained-rustup CARGO_HOME=/opt/maintained-cargo "$rustup_bin" toolchain install 1.95.0 --no-self-update --profile minimal --target aarch64-apple-darwin
   sudo cp "$rustup_bin" /opt/maintained-cargo/bin/rustup
   for tool in cargo rustc rustdoc; do sudo ln -sf rustup "/opt/maintained-cargo/bin/$tool"; done
   if id solidcraft-build >/dev/null 2>&1; then exit 1; fi
   test -z "$(dscl . -search /Users UniqueID 59999)"
   sudo dscl . -create /Users/solidcraft-build
   sudo dscl . -create /Users/solidcraft-build UniqueID 59999
   sudo dscl . -create /Users/solidcraft-build PrimaryGroupID 20
   sudo dscl . -create /Users/solidcraft-build NFSHomeDirectory "$root/home"
   sudo dscl . -create /Users/solidcraft-build UserShell /usr/bin/false
   cat > /tmp/maintained-offline.sb <<'PROFILE'
(version 1)
(deny default)
(allow file-read*)
(deny file-read* (subpath "/Users/runner"))
(allow file-write* (subpath "/private/var/lib/solidcraft") (subpath "/var/lib/solidcraft") (literal "/dev/null"))
(allow process* sysctl-read mach-lookup ipc-posix* signal)
(deny network*)
PROFILE
   sudo install -m 0644 /tmp/maintained-offline.sb /opt/maintained-harness/offline.sb
   ;;
 prefetch|isolation|build)
   developer_dir=$(xcode-select -p)
   script=/opt/maintained-harness/macos.sh
   if [[ "$phase" == prefetch ]]; then
     sudo -u solidcraft-build /usr/bin/env -i HOME="$root/home" CARGO_HOME="$root/cargo" RUSTUP_HOME=/opt/maintained-rustup PATH=/opt/maintained-cargo/bin:/usr/bin:/bin TMPDIR="$root/tmp" DEVELOPER_DIR="$developer_dir" /bin/bash "$script" fetch-inner
   else
     sudo -u solidcraft-build /usr/bin/env -i HOME="$root/home" CARGO_HOME="$root/cargo" RUSTUP_HOME=/opt/maintained-rustup PATH=/opt/maintained-cargo/bin:/usr/bin:/bin TMPDIR="$root/tmp" DEVELOPER_DIR="$developer_dir" CARGO_BUILD_JOBS=3 CARGO_INCREMENTAL=0 CARGO_NET_OFFLINE=true MACOSX_DEPLOYMENT_TARGET=14.0 /usr/bin/sandbox-exec -f /opt/maintained-harness/offline.sb /bin/bash "$script" "$phase-inner"
   fi
   ;;
 fetch-inner)
   cd "$root/source"
   cargo +1.95.0 fetch --locked --target aarch64-apple-darwin
   ;;
 isolation-inner)
   /usr/bin/python3 - <<'PY'
import os,pathlib,socket
assert os.getuid()==59999
assert not any(k in os.environ for k in ['GH_TOKEN','GITHUB_TOKEN','ACTIONS_RUNTIME_TOKEN','SSH_AUTH_SOCK'])
try:list(pathlib.Path('/Users/runner').iterdir())
except (PermissionError,FileNotFoundError):pass
else:raise SystemExit('runner home is readable')
try:socket.create_connection(('1.1.1.1',443),timeout=2)
except OSError:pass
else:raise SystemExit('outbound networking is available')
print('PASS: macOS unprivileged UID, clean environment, protected runner home, denied network')
PY
   ;;
 build-inner)
   ulimit -t 2400
   cd "$root/source"
   cargo +1.95.0 build --target aarch64-apple-darwin --profile ci --locked --offline -p solidcraft -p solidcraft-cli
   target/aarch64-apple-darwin/ci/solidcraft --help
   target/aarch64-apple-darwin/ci/solidcraft-cli --help
   /usr/bin/codesign --verify target/aarch64-apple-darwin/ci/solidcraft
   ;;
 *) exit 2;;
esac

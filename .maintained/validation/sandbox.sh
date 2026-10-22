#!/usr/bin/env bash
set -euo pipefail
phase=$1
network=yes
offline=true
if [[ "$phase" == prefetch ]]; then network=no; offline=false; fi
sudo systemd-run --quiet --wait --pipe --collect --unit="maintained-${phase}" \
  -p User=solidcraft-build -p Group=solidcraft-build \
  -p WorkingDirectory=/var/lib/solidcraft/source \
  -p ProtectSystem=strict -p ProtectHome=yes -p PrivateTmp=yes \
  -p PrivateDevices=yes -p "PrivateNetwork=$network" \
  -p ReadWritePaths=/var/lib/solidcraft \
  -p 'InaccessiblePaths=-/home/runner -/run/docker.sock -/var/run/docker.sock' \
  -p NoNewPrivileges=yes -p CapabilityBoundingSet= -p RestrictSUIDSGID=yes \
  -p ProtectKernelTunables=yes -p ProtectKernelModules=yes -p ProtectControlGroups=yes \
  -p RestrictNamespaces=yes -p LockPersonality=yes -p RemoveIPC=yes \
  -p MemoryMax=12G -p MemorySwapMax=0 -p TasksMax=1024 -p RuntimeMaxSec=3000 \
  /usr/bin/env -i HOME=/var/lib/solidcraft/home \
  CARGO_HOME=/var/lib/solidcraft/cargo RUSTUP_HOME=/opt/maintained-rustup \
  PATH=/opt/maintained-cargo/bin:/usr/bin:/bin \
  CARGO_BUILD_JOBS=3 CARGO_INCREMENTAL=0 CARGO_TERM_COLOR=never \
  CARGO_NET_OFFLINE="$offline" RUST_BACKTRACE=1 \
  XDG_RUNTIME_DIR=/var/lib/solidcraft/runtime \
  VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.x86_64.json \
  /bin/bash /opt/maintained-harness/task.sh "$phase"

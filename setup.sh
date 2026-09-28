#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "IASI Ecosystem Setup"
echo "===================="
echo
echo "This repository contains the installation guide, binaries, scripts and configuration required to assemble the IASI ecosystem."
echo
echo "Current stage: installation procedure validation."
echo "Follow the guide in: guide/"
echo

if [[ -x "$ROOT/bin/sh/setup.sh" ]]; then
  "$ROOT/bin/sh/setup.sh"
fi

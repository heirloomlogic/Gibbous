#!/usr/bin/env bash
#
# One-shot Git LFS setup for Gibbous.
#
# The Moon textures, sounds, fonts, and app-icon art are stored as Git LFS
# objects (see .gitattributes). Without Git LFS they clone as small pointer
# files, and the build fails with the opaque "Distill failed for unknown
# reasons" (Xcode can't read the app-icon PNG). This script installs Git LFS
# if needed, registers its hooks, and pulls the real binary assets into an
# existing clone. Safe to run repeatedly.
set -euo pipefail

if ! command -v git-lfs >/dev/null 2>&1; then
  echo "Git LFS not found. Attempting to install..."
  if command -v brew >/dev/null 2>&1; then
    brew install git-lfs
  else
    echo "error: Git LFS is required but not installed, and Homebrew was not found." >&2
    echo "       Install it from https://git-lfs.com and re-run this script." >&2
    exit 1
  fi
fi

echo "Registering Git LFS hooks..."
git lfs install

echo "Pulling Git LFS assets..."
git lfs pull

echo "Done. Git LFS assets are ready — open Gibbous.xcodeproj and build."

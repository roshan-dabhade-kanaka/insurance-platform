#!/usr/bin/env bash
# Clean install for Git Bash (remove node_modules and package-lock, then npm install)
cd "$(dirname "$0")/.." || exit 1
echo "Removing node_modules and package-lock.json..."
rm -rf node_modules
rm -f package-lock.json
echo "Running npm install..."
npm install

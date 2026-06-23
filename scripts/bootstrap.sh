#!/usr/bin/env bash
# Bootstrap the Shotgun dev environment.
# Installs the tools we depend on, creates a local secrets file, and generates
# the Xcode project. Safe to re-run.
set -euo pipefail

cd "$(dirname "$0")/.."

info()  { printf "\033[36m==>\033[0m %s\n" "$1"; }
warn()  { printf "\033[33m!! \033[0m %s\n" "$1"; }

if ! command -v brew >/dev/null 2>&1; then
  warn "Homebrew not found. Install it from https://brew.sh then re-run."
  exit 1
fi

install_if_missing() {
  local bin="$1" formula="$2"
  if command -v "$bin" >/dev/null 2>&1; then
    info "$bin already installed"
  else
    info "Installing ${formula}..."
    brew install "$formula"
  fi
}

info "Checking developer tools"
install_if_missing xcodegen xcodegen
install_if_missing swiftlint swiftlint
install_if_missing supabase supabase/tap/supabase

if [ ! -f Config/Secrets.xcconfig ]; then
  info "Creating Config/Secrets.xcconfig from template"
  cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
  warn "Edit Config/Secrets.xcconfig with your Supabase URL + anon key."
else
  info "Config/Secrets.xcconfig already exists"
fi

info "Generating Xcode project"
xcodegen generate

info "Done. Next:"
echo "  1. Edit Config/Secrets.xcconfig with your Supabase credentials"
echo "  2. Run 'make open' to open the project in Xcode"
echo "  3. Set your Apple Developer team in the target's Signing & Capabilities"

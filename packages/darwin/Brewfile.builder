# Brewfile.builder — the self-hosted CI builder Mac (workhorse).
# Applied ON TOP of Brewfile.core/personal: brew bundle --file=packages/darwin/Brewfile.builder
# See docs/mac-builder.md for the full runbook (runner, keychain, energy).

brew "node@22"          # keg-only; PATH-pinned in ~/.zprofile for terminal builds
brew "cocoapods"
brew "fastlane"         # eas build --local shells out to gym
brew "gh"
brew "xcodes"           # keep Xcode current from the CLI
brew "android-commandlinetools"
cask "temurin@17"       # gradle's JDK

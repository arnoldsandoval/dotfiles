# The builder Mac (workhorse)

A Mac registered as a self-hosted GitHub Actions runner for the
`panchoinc` org, building iOS and Android for the Expo apps (gorilla,
swappy) via `eas build --local`. Signing stays EAS-managed (EXPO_TOKEN);
only compute lives here. Shared pipeline: `panchoinc/build` →
`.github/workflows/expo-native-build.yml`; each app has a ten-line
caller (`native-builds.yml`).

## Rebuild from a clean Mac

1. Xcode from the App Store; open once; `sudo xcodebuild -runFirstLaunch`.
2. `./bootstrap` (mac-personal), then
   `brew bundle --file=packages/darwin/Brewfile.builder`.
3. `echo 'export PATH="/opt/homebrew/opt/node@22/bin:$PATH"' >> ~/.zprofile`
4. Android: `yes | sdkmanager --licenses`, then
   `sdkmanager "platform-tools" "platforms;android-36"`. Gradle pulls NDK
   versions itself once licenses are accepted.
5. **Apple WWDR intermediates** — a fresh Mac lacks the generations that
   validate EAS distribution certs; without them every build dies with
   "certificate hasn't been imported successfully":
   `for g in G3 G4 G5 G6 G7 G8; do curl -fsSLo /tmp/w$g.cer https://www.apple.com/certificateauthority/AppleWWDRCA$g.cer && security import /tmp/w$g.cer -k ~/Library/Keychains/login.keychain-db; done`
6. Auto-login ON (Users & Groups) — signing needs an unlocked login
   keychain in a real GUI session, unattended reboots included.
7. Runner: repo/org Settings → Actions → Runners → New self-hosted
   runner (macOS arm64), register against the ORG with default labels,
   then `./svc.sh install && ./svc.sh start`. If installed over SSH,
   re-bootstrap into the GUI domain or the keychain import fails:
   `launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/actions.runner.*.plist; launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/actions.runner.*.plist`
8. Energy: prevent sleep on power adapter when display is off; a display
   (or dummy plug) enables clamshell. On battery it may sleep — jobs
   queue ~a day; the workflow's `runner: github-hosted` input is the
   travel fallback.

## Secrets

Org-level Actions secrets on panchoinc: `EXPO_TOKEN` (Expo access
token), ASC key trio for TestFlight submits. Set with
`gh secret set --org panchoinc`; never through chat or commits.

## Notes

- Runner service is the ONLY always-on process; Tailscale is for remote
  access (SSH/VNC), not builds.
- Self-hosted runners attach to PRIVATE repos only — a fork PR on a
  public repo could execute code on this machine.
- Ad-hoc install page pattern (Expo-style, tailnet-only): manifest.plist
  + IPA served over `tailscale serve` https, `itms-services://` link.

## The runtime-version rule (learned 2026-08-31, the hard way)

`runtimeVersion = appVersion` in the Expo apps, and version is the OTA
compatibility wall. ANY build that changes natives (new module, pod
bumps, expo patch bumps) MUST bump the app version — otherwise the new
binary downloads OTAs published for the old natives and expo-updates
ErrorRecovery.crash()es on every launch after the first ("instantly
crashes, doesn't open"). Symptom in the .ips: SIGABRT on
expo.controller.errorRecoveryQueue. Old binaries freeze safely on their
last matching OTA when the version moves; that's the design working.

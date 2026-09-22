---
name: build
description: >
  Produces native release artifacts for every platform by running the build on
  GitHub Actions: Android APK/AAB, Tauri binaries for Linux, Windows and macOS,
  iOS on a macOS runner, and the web bundle. Use when someone asks for a
  release, an APK, an installer, a build for a platform this machine cannot
  target, or wants to know whether the project still builds everywhere. Runners
  supply the SDKs and Xcode, so no local toolchain is needed and no target is
  blocked by the operating system you happen to be on.
---

# Build every platform on GitHub Actions

One machine cannot build this stack. Xcode only runs on macOS, Tauri for
Windows needs Windows, and installing an Android SDK everywhere is a chore.
Runners already have all three, so the build goes there instead.

**On a public repository this is free.** Standard runners cost nothing for
public repos, including the macOS and Windows ones. On a private repository the
Free plan gets 2,000 minutes a month, and minutes are not equal: macOS bills at
roughly ten times Linux and Windows at about 1.7 times. Mention that before
enabling anything that runs macOS jobs on every push.

## What the runners already have

Nothing here needs installing, which is the main reason this is worth doing:

| Runner | Ships with | Builds |
|---|---|---|
| `ubuntu-latest` | Android SDK at `/usr/local/lib/android/sdk`, JDK, Rust | Web, Android, Tauri Linux |
| `macos-latest` | Xcode, Rust, CocoaPods | iOS, Tauri macOS |
| `windows-latest` | MSVC, WebView2, Rust | Tauri Windows |

The Android SDK being preinstalled is worth knowing: it removes the JDK version
and `ANDROID_HOME` problems that bite on a developer machine.

## Install the workflow

```bash
mkdir -p .github/workflows
cp ${CLAUDE_PLUGIN_ROOT}/skills/build/assets/build.yml .github/workflows/
```

Read it before committing rather than pasting it blind. Two things usually need
a decision:

- **Which platforms.** The matrix builds all of them. Delete the entries the
  project does not ship, because every job costs minutes and adds a way to fail.
- **When it runs.** It is set to `workflow_dispatch` and version tags, not every
  push, because a full native build on each commit is slow and wasteful. The web
  build and `/multi-platform:apptest` are what should gate ordinary pushes.

## Run it

```bash
gh workflow run build.yml                 # current branch
gh workflow run build.yml --ref v1.2.0    # a tag
gh run watch                              # follow it
gh run download                           # artifacts, once it finishes
```

If `gh` is not authenticated, say so and stop rather than pushing a commit to
trigger the workflow by side effect.

## Report per platform

A build that half worked is the normal outcome, and the summary has to show
that. Give a line per target with its artifact, and name the failing step for
anything that did not build:

```
web       ok    build/           1.1 MB
android   ok    app-debug.apk    4.3 MB
linux     ok    tally_1.0.0.deb  8.1 MB
windows   FAIL  MSVC link error in tauri-build (job log, step 7)
ios       ok    App.app          simulator build, unsigned
```

Do not report a matrix as successful because the workflow finished; a matrix
with `fail-fast: false` completes with failures in it by design.

## Signing

Unsigned artifacts are the default here and that is deliberate. A simulator
build, a debug APK and an unsigned desktop binary are all useful for testing and
need no secrets.

Shipping to a store or to users needs signing identities, which are real
secrets: an Android keystore, an Apple certificate and provisioning profile, a
Windows code-signing certificate. Those belong in repository secrets, added by
the user. Never ask for a certificate or password in the conversation, and never
write one into a workflow file.

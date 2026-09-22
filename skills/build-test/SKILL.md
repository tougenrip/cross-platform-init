---
name: build-test
disable-model-invocation: true
argument-hint: "[all|web|android|ios|desktop]"
description: >
  Builds every platform and then exercises each artifact on a real runtime: an
  Android emulator, an iOS simulator, and the desktop binaries. Use before a
  release, when a native capability needs verifying, or when a bug reproduces on
  a device but not in a browser. This is slow and, on a private repository,
  expensive, so it is a release gate rather than a per-push check. For ordinary
  work use /multi-platform:apptest, which covers most of the same code for free.
---

# Build and test on real runtimes

**This skill is user-invoked only.** `disable-model-invocation: true` means
Claude cannot start it on its own, and that is deliberate: a full matrix can
consume a real share of a private repository's monthly minutes, and spending
someone's CI budget is not a call to make on their behalf. When a task seems to
need it, say so and let the user type the command.

`/multi-platform:apptest` covers most of what people actually want here, costs
nothing, and Claude can run that freely.

This runs the native artifacts on emulated hardware. It is the only way to see
the failures that never appear in a desktop browser, and it costs enough that it
should not run on every push.

## Say what it costs before running it

On a **public repository** standard runners are free, so the cost is wall-clock:
expect 30 to 60 minutes for a full matrix, with the emulator and simulator jobs
dominating.

On a **private repository** it bills against 2,000 free minutes a month on the
Free plan, and the rates differ sharply: macOS is roughly ten times Linux,
Windows about 1.7 times. A full build-and-test matrix can consume a meaningful
share of a month's allowance in a handful of runs. Tell the user which case they
are in before starting, and suggest `/multi-platform:apptest` if the thing they
want checked does not actually need a device.

## What this catches that a browser cannot

This is the justification for the expense, and it is worth being concrete. Bugs
in this class have real precedent in this stack:

- A WebView blocking a plain `http://` request as mixed content, because
  Capacitor serves Android from `https://localhost` while iOS uses
  `capacitor://localhost`. Identical code, one platform fails.
- Android rejecting cleartext HTTP with nothing useful in any log.
- An emulator needing `10.0.2.2` where a browser wants `localhost`.
- Native plugin behaviour: camera, filesystem, push, deep links, biometrics.
- A desktop binary that compiles and then fails to open a window.

## Arguments

`/multi-platform:build-test [all|web|android|ios|desktop]`

`$ARGUMENTS` is a space-separated list of platforms, empty when omitted:

- **Empty** means the user has not chosen yet. Ask.
- **Named platforms** narrow the run. `build-test android` builds one job instead of
  five, which is the difference between a couple of minutes and the better part
  of an hour. Prefer narrowing whenever the request is about one platform.
- **Anything unrecognised**: say so and ask, rather than silently running
  everything. Running the full matrix because a word was misspelled is an
  expensive way to be wrong.

**If no platforms were given, ask which. Do not assume all of them.**

An omitted argument expands to an empty string, which means the user has not
chosen, not that you may choose the most expensive option on their behalf.
Running the full matrix is the costliest thing this skill can do, so it is the
last thing to do by default. Ask, list what the project targets, and wait.

Running unattended, stop and return the question rather than guessing.

Pass the selection through to the workflow with `gh workflow run -f platforms=...`
when the workflow exposes that input, and otherwise filter the matrix locally.

## Install the workflow

```bash
mkdir -p .github/workflows
cp ${CLAUDE_PLUGIN_ROOT}/skills/build-test/assets/build-test.yml .github/workflows/
```

It is `workflow_dispatch` only by default. Resist wiring it to `push`.

## Run it

```bash
gh workflow run build-test.yml
gh run watch
```

## The runtimes it uses

**Android.** A hardware-accelerated emulator on `ubuntu-latest`, which is two to
three times faster than the macOS equivalent and far cheaper. It needs a KVM
permission rule, which the workflow sets; without it the emulator falls back to
software rendering and crawls.

**iOS.** A simulator on `macos-latest` via `xcrun simctl`. No signing identity
is involved, so no secrets are needed.

**Desktop.** The Linux binary runs under `xvfb`, since a runner has no display.
Windows and macOS runners have one already.

## Reading the result

Report per platform, and treat a finished matrix as inconclusive until you have
looked: `fail-fast: false` means the run completes with failures inside it.

When a native test fails, the device log is where the answer is, not the test
output. `adb logcat` on Android surfaces WebView errors that appear nowhere
else, and the simulator log does the same on iOS. A request blocked by the
WebView never reaches the network, so the server log stays empty and the screen
shows nothing.

## Real devices

Emulators do not catch everything. A physical phone sits on a different network
than the host, which is the single difference behind several of the hardest bugs
in this stack: an emulator reaching the host at `10.0.2.2` proves nothing about
a phone that needs the host's LAN address.

Free options, when that matters:

- **Firebase Test Lab**, Spark plan: 5 physical-device and 10 virtual-device
  test runs per day at no cost and with no billing account. Enough for a release
  gate.
- **BrowserStack** and **LambdaTest** both run free tiers for open-source
  projects.

Real iOS hardware stays the hardest case: it needs a signing identity, so it
belongs on a developer's own machine rather than in CI.

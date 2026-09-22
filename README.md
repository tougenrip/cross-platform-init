# multi-platform

One SvelteKit codebase targeting **web, Android, iOS, Windows, macOS and Linux**,
with a Dockerized backend behind it. Native builds run on GitHub Actions, so no
single machine has to own every toolchain.

Every instruction in this plugin was verified by running it: on Ubuntu, on a
Samsung phone over adb, and on a Mac over SSH. The things that only appear on
real hardware are written down because they happened, not because they seemed
likely.

## Install

```
/plugin marketplace add tougenrip/multi-platform
/plugin install multi-platform@multi-platform
```

From a shell instead:

```bash
claude plugin marketplace add tougenrip/multi-platform
```

To pick up later changes:

```bash
claude plugin marketplace update multi-platform
```

## The four skills

| Skill | What it does | Cost |
|---|---|---|
| `/multi-platform:init [app-name] [supabase\|postgres]` | Scaffolds the app and the backend | Local |
| `/multi-platform:apptest [spec-or-pattern]` | Playwright against the web build | Free, seconds |
| `/multi-platform:build [platforms]` | Native artifacts on GitHub Actions | Free on public repos |
| `/multi-platform:build-test [platforms]` | Build, then run on emulator and simulator | Slow; metered on private repos |

All arguments are optional and omitting one is not an error:

```
/multi-platform:init Ledger postgres     scaffolds without asking anything
/multi-platform:init Ledger              Supabase by default, stated in a line
/multi-platform:init                     asks for the name, nothing else
/multi-platform:build android            one job, not five
/multi-platform:apptest e2e/todo.spec.ts one spec while you iterate
```

Narrowing matters on the build skills: `build android` is a couple of minutes
where the full matrix is the better part of an hour.

**Use `apptest` by default.** Capacitor and Tauri wrap the same static bundle,
so anything that is not calling a native API behaves the same in a browser.
Most bugs surface there in seconds instead of in a forty-minute native matrix.

Reach for `build-test` when the thing under test genuinely cannot happen in a
browser: WebView networking, plugin behaviour, app lifecycle.

## Hand the install to an agent

The plugin ships a `stack-installer` agent for when you want the stack stood up
rather than explained:

> Use the stack-installer agent to set up a multi-platform app called Ledger

Include the name. An agent has no conversation to ask into, so rather than
inventing one it stops and asks: the name lands in four places and renaming
later means regenerating the native projects.

## What the stack is

A static SvelteKit SPA, because Capacitor and Tauri both ship files rather than
a Node server. That one constraint drives everything else: no SSR, no server
routes, `adapter-static` with a fallback, and a backend that lives in its own
containers.

**Backend, pick one.** Local Supabase is the default and collapses Postgres, a
REST API, storage and auth into one dependency. Postgres + your own API server +
MinIO is there when you need an API shape PostgREST will not give you. Redis
either way.

**Builds.** `ubuntu-latest` already has the Android SDK, `macos-latest` already
has Xcode, `windows-latest` has MSVC and WebView2. Nothing needs installing, and
standard runners are free for public repositories.

## Check your machine first

```bash
bash ~/.claude/plugins/marketplaces/multi-platform/skills/init/scripts/preflight.sh web backend desktop android ios
```

It reports what is missing and installs nothing, because several fixes need
`sudo` and that is yours to decide. It checks for the thing being *selected* and
*running*, not merely present: a JDK that is installed but not the default, an
Xcode that exists while `xcode-select` points at the Command Line Tools, an
`ANDROID_HOME` set in a shell config a non-interactive shell never reads.

## Things that cost an evening to learn

- SvelteKit no longer generates `svelte.config.js`. The adapter is configured
  inside the `sveltekit()` plugin in `vite.config.ts`.
- `--no-add-ons` gives you `adapter-auto`, which emits something no native shell
  can load.
- `tauri init` has no identifier flag. It writes `com.tauri.dev` and refuses to
  bundle until you change it.
- Capacitor 8 uses Swift Package Manager, so there is no `App.xcworkspace` and
  CocoaPods is not needed to start.
- A freshly installed Xcode 26 contains **no iOS platform**. Nothing builds
  until `xcodebuild -downloadPlatform iOS` finishes.
- Android serves the app from `https://localhost`, so a plain `http://` API call
  is blocked as mixed content. iOS uses `capacitor://localhost` and is fine.
  Same code, one platform fails.
- `VITE_` values are inlined at build time. Editing `.env` changes nothing until
  you rebuild and `cap sync`.

## Layout

```
.claude-plugin/          marketplace.json, plugin.json
agents/stack-installer.md
skills/
├── init/                scaffold: SKILL.md, references/, scripts/preflight.sh
├── apptest/             Playwright: SKILL.md, assets/apptest.yml
├── build/               native builds: SKILL.md, assets/build.yml
└── build-test/          emulator + simulator: SKILL.md, assets/build-test.yml
```

## Limits

iOS and macOS builds need a Mac, which is what the GitHub Actions runners are
for. Real-device testing is not covered by emulators: a phone sits on a
different network than the host, which is the difference behind several of the
hardest bugs here. Firebase Test Lab's free tier gives 5 physical and 10 virtual
device runs a day if that matters.

MIT.

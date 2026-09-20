# cross-platform-init

A [Claude Code skill](https://docs.claude.com/en/docs/claude-code/skills) that scaffolds a
single codebase targeting **web, Android, iOS and desktop**, with a Dockerized backend behind
it, and gets it to the point where all of those actually build and run.

Stack: SvelteKit (static SPA) + Capacitor (mobile) + Tauri (desktop), talking to either local
Supabase or Postgres + a custom API + MinIO, with Redis alongside.

The value is not the file list. It is the ~30 things that break on the way there, each of
which is documented with its real symptom, because almost none of them fail in a way that
names the actual cause.

## Install

Skills live in `~/.claude/skills/`, either globally or per project:

```bash
git clone git@github.com:tougenrip/cross-platform-init.git /tmp/cpi
cp -r /tmp/cpi/cross-platform-init ~/.claude/skills/
```

Confirm Claude can see it by asking it to list your skills, or just describe a
cross-platform app and watch whether it loads.

## Using it

Describe what you want to build. The skill is written to trigger before you finish
explaining, because the SSR and adapter decisions it makes are baked in at scaffold time and
are expensive to unwind afterwards.

It asks for one thing, your app's name, because that name propagates into the directory,
`package.json`, the window title and the bundle identifier. Everything else it decides and
tells you: the workspace becomes the project directory, the bundle id is derived, the backend
defaults to Supabase, and targets follow whatever toolchains you actually have.

### Check your machine first

```bash
bash ~/.claude/skills/cross-platform-init/scripts/preflight.sh web backend desktop android ios
```

Pass only the targets you care about. It reports what is present, what is missing and the
exact command for your platform, and it installs nothing: several fixes need `sudo`, and that
is your call rather than an agent's.

It is deliberately careful about the difference between absent and merely unusable. On real
machines "missing" is usually one of: not on this shell's PATH, installed but not selected,
installed but the wrong version, a variable set in a shell config the agent never reads, or a
daemon that is not running. Each of those wants a different fix and none of them is
"install it".

## Verified, not asserted

Every claim in the skill was executed on real hardware. Where a claim could not be tested, it
says so rather than guessing.

| Target | Status | Verified by |
|---|---|---|
| Web | Working | Build, then full CRUD against a live Postgres |
| Android | Working | APK built, installed on a physical Samsung, live reads and writes |
| iOS | Working | Simulator on macOS 26, live data across the LAN |
| Linux desktop | Working | Tauri window built and launched |
| Windows desktop | **Untested** | No Windows machine available |

Windows is the honest gap. The Tauri source is shared with Linux, but nothing has been run
there, and on this project's record that means it probably hides two or three problems.

## What it knows that you would otherwise learn the hard way

A sample, all found by running things rather than reading documentation:

- `svelte.config.js` no longer exists. Current SvelteKit configures the adapter inside the
  `sveltekit()` plugin in `vite.config.ts`.
- Scaffolding without the static adapter add-on silently gives you `adapter-auto`, which
  emits something no native shell can load.
- Android blocks cleartext HTTP, and Capacitor does **not** exempt it for you.
- Even with cleartext allowed, Android serves the app from `https://localhost`, so an
  `http://` API is blocked as mixed content. That is a separate mechanism, invisible outside
  `adb logcat`, and the fix is `androidScheme: 'http'` under `server`, not under `android`.
- iOS has no equivalent problem, because it serves from `capacitor://localhost`, which is not
  an HTTPS origin. Do not add ATS exemptions to fix a problem you do not have.
- Xcode 26 installs with no iOS platform. Nothing builds until you download it, and the error
  says `Found no destinations for the scheme`.
- CocoaPods is not needed to start. Capacitor 8 generates a Swift Package Manager project, so
  there is no `App.xcworkspace` and most build snippets online now fail.
- MinIO is no longer on Docker Hub. The pull fails with an authentication error that sends
  people hunting for credentials they do not need.
- `VITE_` variables are inlined at build time, so editing `.env` changes nothing on a device
  until you rebuild and re-sync.

## Layout

```
cross-platform-init/
├── SKILL.md                              the workflow
├── references/
│   ├── backend-supabase.md               default backend
│   └── backend-postgres-minio.md         Postgres + custom API + MinIO
└── scripts/
    └── preflight.sh                      prerequisite checker
```

The two backend files are alternatives, not layers. The skill reads whichever one it picks.

## A note on the checks

`preflight.sh` covers the failures encountered so far, not every way a machine can differ. If
it passes and a build still fails, the script is incomplete rather than the machine wrong:
find the real cause, fix the script, and say what changed.

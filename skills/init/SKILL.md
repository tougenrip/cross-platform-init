---
name: init
argument-hint: "[app-name] [supabase|postgres]"
arguments: [name, backend]
description: >
  Scaffolds the project: SvelteKit + Capacitor + Tauri targeting web, Android,
  iOS and desktop, with a Dockerized backend behind it (local Supabase, or
  Postgres + API server + MinIO) and a Redis cache. Use this BEFORE the user
  finishes describing what they want to build, the moment they mention starting
  a cross-platform app, a Svelte app, Capacitor or Tauri, or an app that runs on
  mobile and desktop, so the foundation exists before any feature work. Also use
  when adding Capacitor, Tauri, a database, object storage, a cache or Docker
  Compose to an existing Svelte project, when the user asks for a local dev
  stack or "the whole backend", or when a build fails on mobile or desktop
  because of SSR or adapter misconfiguration. Once a project exists, testing is
  /multi-platform:apptest and native artifacts are /multi-platform:build.
---

# Cross-platform base: SvelteKit + Capacitor + Tauri

Sets up one Svelte codebase targeting web, iOS/Android (Capacitor), and desktop (Tauri).

## Do this first

Run the scaffold **before** the user finishes describing their project. Rationale: SSR, adapter, and build-output decisions are baked in at `sv create` time, and unwinding them after feature code exists is far more work than doing it up front. A two-minute scaffold now saves an afternoon later.

If the user is mid-description, scaffold while you listen — don't block them on it.

The one thing you genuinely need before starting is a name, because it lands in four places at once (see the next section). If they have given one, take it and go. If they haven't, ask for that single thing and keep listening while they answer; it is a one-line question, not a reason to stop. Everything else has a defensible default, so decide it, state what you chose in a line, and move — the point of scaffolding early is lost if it turns into an intake interview.

## The one constraint that governs everything

Capacitor and Tauri both ship a **static bundle of files**, not a Node server. So:

- No SSR, no server routes, no `+page.server.ts`, no form actions.
- `adapter-static` with `fallback` (SPA mode), because native shells can't do per-route prerendering of dynamic paths.
- Backend work goes to an external API you call with `fetch`, not to SvelteKit server code.

If the user later asks for something needing a server, say so plainly and point at the backend below or at Tauri commands (Rust side) — don't quietly re-enable SSR, which breaks both native targets.

This is exactly why the backend is a separate Dockerized stack rather than SvelteKit server routes: the frontend has to stay a static bundle, so the server has to live somewhere else regardless. Scaffolding it now means `fetch` has something real to talk to from the first feature.

## Arguments

`/multi-platform:init [app-name] [supabase|postgres]`

Both are optional and both expand to an empty string when omitted, so branch on
whether they arrived:

| Value | Given | Empty |
|---|---|---|
| `$name` | Use it. Do not ask again. | Ask for it. It is the one thing you cannot invent. |
| `$backend` | `supabase` or `postgres` selects the variant; anything else, treat as unset and say why. | Ask which, with the trade-off in a line each. |

**If an argument was not given, ask for it. Do not pick one.**

An omitted argument expands to an empty string, so this is unambiguous: empty
means the user has not chosen, not that you may choose for them. Put the options
in front of them and wait. A default chosen silently is a decision the user never
made, and they usually find out when it is expensive to undo.

Running unattended, with no conversation to ask into, is the one exception:
stop and return the question instead of guessing. A run that ends asking for one
value costs far less than one that quietly built the wrong thing.

So `/multi-platform:init Ledger postgres` reaches the scaffold without a single
question, `/multi-platform:init Ledger` asks only about the backend, and
`/multi-platform:init` asks for both, together, in one message rather than two.

This applies to the two declared arguments, not to everything. The directory,
bundle identifier and target platforms are all inferred, and those keep their
defaults: state what you chose in a line and move on. The difference is that a
declared argument is a question the skill promised to ask.

## Check prerequisites first, and report honestly

Run the bundled preflight before any install, passing only the targets the user actually asked for:

```bash
bash <skill-dir>/scripts/preflight.sh web backend desktop android
```

It checks Node, Docker and its daemon, Rust plus the Linux system libraries Tauri needs, JDK version and `ANDROID_HOME`, and Xcode plus the iOS platform on macOS. It installs nothing, because several fixes need `sudo` and that is the user's decision.

### Establish what is actually there before prescribing anything

Telling someone to install software they already have is worse than saying nothing: they lose time, they may end up with two copies, and they stop trusting the rest of your diagnosis. On real machines "missing" almost always turns out to be one of these, and each wants a different fix:

| What you observe | What it usually means | What to check |
|---|---|---|
| Command not found | Installed, but not on *this* shell's PATH. Agent shells are non-interactive and read no `.bashrc`/`.zshrc` | The usual install roots: `/opt/homebrew/bin`, `/usr/local/bin`, `~/.cargo/bin`, `~/.local/bin`, nvm/fnm/volta/asdf shims |
| Tool present, builds still fail | Installed but not *selected* | `xcode-select -p`, `update-alternatives`, `JAVA_HOME`, whichever version manager is in play |
| Tool present, wrong version | Several installed, the default is old | List the install directory, not just `--version` on the first hit |
| Env var unset | Set in the user's shell config, invisible here | Probe the conventional path (`~/Android/Sdk`) before reporting it |
| Daemon/service absent | Installed but not running | `docker info`, not `which docker` |
| SDK present, builds still fail | The platform or runtime is a separate download | `xcrun simctl list runtimes`, SDK manager contents |

The habit that follows: when something looks absent, spend one command finding out *why* before writing a single install instruction. `ls` the directory where it would live. Ask what the active selection is. Check whether a daemon answers.

**This list is what we have hit so far, not the full set of ways a machine can surprise you.** When the preflight passes and something still fails, the script is incomplete, not the machine wrong. Diagnose the real cause, fix the script, and say what changed. The same applies when a fix needs `sudo`: report it and let the user run it, then re-run the preflight to confirm it took, because a package can land and still leave the environment pointing somewhere else.

Two reasons this goes first. Prerequisite failures surface late and wear a disguise: Tauri compiles two hundred crates before panicking on a missing `.pc` file, and a Java 8 JDK passes every "is java installed" check then fails inside Gradle. Finding both in two seconds beats finding them after a ten-minute build.

**When something is missing, say so plainly and carry on with what works.** A blocked target is not a reason to stop — the web build, the backend and the other platforms are all still worth having. Give the user the exact command for their platform, tell them which target it unblocks, and finish everything else. What you must not do is quietly skip a target and let the summary imply it was built, or "work around" a missing toolchain by substituting something the user did not ask for.

Verify a fix rather than assuming it worked: re-run the preflight after they install, since a package can land and still leave the environment variable unset.

## Settle the basics before running anything

Every scaffolding command below prompts for something. In a terminal that is fine. In an agent session an unanswered prompt does not fail — it **hangs**, waiting on stdin that never arrives, with no output and no error. So collect the answers first and pass them as flags.

**Infer first, ask only for the gap.** If the user said "a habit tracker called Cadence", the name is Cadence and the directory is the current workspace. Use them and say so in one line. A questionnaire in front of someone who already told you what they want is its own kind of failure.

| Value | Where it comes from |
|---|---|
| App name | `$name` if given, otherwise the user's request. This is the one worth asking for when it is genuinely absent. |
| Directory | The current workspace, unless the user named somewhere else. Don't ask. |
| Bundle identifier | Derive it (below). Mention the default rather than asking. |
| Targets (iOS / Android / desktop) | The user's request; default to all, add only what their toolchain supports. |
| Backend variant | `$backend` if given, otherwise the section further down; default Supabase. |

Ask for the app name when it is missing because it propagates: the directory, `package.json` name, window title, and bundle identifier all derive from it, and changing it afterwards means editing all four plus regenerating the native projects. One question up front is cheaper than that.

### Deriving everything else from the name

```
Display name   Cadence                  window title, cap init argument
Directory      cadence                  lowercase, spaces to hyphens
npm name       cadence                  package.json; npm rejects capitals and spaces
Bundle id      com.example.cadence      reverse-DNS
```

**The bundle id is not the directory name with dots.** `cap init` validates it and states the rules plainly: Java package form with no dashes, at least two segments, each segment starting with a letter, and only alphanumerics or underscore throughout. An app named "my habit tracker" therefore gives the directory `my-habit-tracker` but the bundle id `com.example.myhabittracker` — strip the hyphens rather than carrying them across.

Capacitor rejects a bad id immediately and tells you exactly why, which is the good case. Two ways to lose that safety net: passing `--skip-appid-validation`, and Tauri, which validates nothing at init and takes its identifier from a file you edit by hand. Derive the id once, use the same string in both places, and neither can bite you.

`com.example.*` is fine for local development. It cannot be submitted to either store, so say that once when you set it rather than letting it surface at release.

## Scaffold

Use `@latest` everywhere rather than pinned versions — these tools move fast and pinned versions in a skill file go stale. Check what actually got installed afterward if something looks off.

`sv create` prompts for the template, language, add-ons *and the package manager*, so all four have to be supplied or it stops and waits. `--no-add-ons` and `--add` are mutually exclusive, and a bare `--add <name>` can still prompt for that add-on's own options — so set every option an add-on lists. Run `npx sv create --help` if in doubt; it documents its own non-interactive usage and the current add-on list.

Two separators, and mixing them up produces `Malformed arguments`: `+` joins *different options* (`a=x:1+y:2`), while a comma joins *multiple values of one option* (`vitest=usages:unit,component`). The failure is at least immediate and explicit rather than silent.

`sveltekit-adapter=adapter:static` is not optional here. Without it you get `adapter-auto`, which resolves a deployment target at build time and emits something no native shell can load.

### Which add-ons to offer

The rest are a real choice, and worth one short question rather than a silent default: *"Want prettier, eslint and vitest? Anything else from the sv list?"* Suggest those three unless the user has a view — they are cheap, and retrofitting a formatter across an existing codebase is a noisy diff nobody enjoys reviewing.

Fine to add, nothing here conflicts with a static bundle:

| Add-on | Note |
|---|---|
| `prettier`, `eslint` | No options to set |
| `vitest=usages:unit,component` | Set usages explicitly or it prompts |
| `playwright`, `storybook` | Dev tooling only |
| `tailwindcss="plugins:none"` | Set plugins explicitly, even to none |
| `mdsvex` | Markdown in components |
| `paraglide` | i18n; runs client-side |
| `ai-tools` | Editor/agent config |

**Do not add these, and say why if the user asks for them.** They assume a server the native builds do not have:

- `drizzle` — a server-side ORM. The frontend ships as static files with no Node process, and a database URL reaching the client bundle is a credential leak. Drizzle belongs in the API server of the Postgres variant, installed there, not here.
- `better-auth` — needs server endpoints for the same reason. Use Supabase auth, or put auth in your own API server.
- `experimental` — its features (remote functions and friends) are server-dependent by design.

The pattern is the constraint from the top of this file reappearing: anything that wants to run code on a server cannot live in the frontend project, because after `npm run build` there is no server left, only files.

```bash
npx sv create <dir> --template minimal --types ts \
  --add sveltekit-adapter=adapter:static <other-add-ons> \
  --install npm
cd <dir>
npm i -D @tauri-apps/cli@latest
npm i @capacitor/core && npm i -D @capacitor/cli
```

### 1. Adapter and SPA mode, in `vite.config.ts`

Current SvelteKit configures the adapter inside the `sveltekit()` Vite plugin. A generated project has **no `svelte.config.js` at all**, so do not create one — edit what `sv create` produced. Adding a second config file invites two sources of truth for the same setting.

Scaffolding with `--add sveltekit-adapter=adapter:static` already installs the adapter and wires it in. One thing it does not do is set the SPA fallback, so open `vite.config.ts` and add it:

```ts
import adapter from '@sveltejs/adapter-static';
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

export default defineConfig({
  plugins: [
    sveltekit({
      adapter: adapter({ fallback: 'index.html' })   // fallback is the SPA part
    })
  ],
  server: { port: 1420, strictPort: true, host: '0.0.0.0' }
});
```

Keep whatever `compilerOptions` the generator wrote — this snippet shows the parts you are changing, not a file to paste over the top. Overwriting it wholesale is how the adapter wiring gets deleted.

Tauri's config hardcodes the dev URL, so the port must not drift — hence `strictPort`. `host: '0.0.0.0'` is what lets a physical phone reach the dev server over LAN.

If you skipped the add-on you will have `adapter-auto` instead, which picks a deployment target at build time and produces something no native shell can load. Swap it: `npm i -D @sveltejs/adapter-static` and change the import.

### 2. Turn off SSR

`src/routes/+layout.ts` (create it):

```ts
export const ssr = false;
export const prerender = false;
```

`ssr = false` is non-negotiable for native shells. `prerender = false` plus the `index.html` fallback gives a plain SPA, which is what a WebView expects.

### 3. Tauri

Tauri compiles a native binary, so it needs system libraries the other targets do not. Rust being installed is not enough, and the failure is confusing: `cargo` builds two hundred crates successfully and only then dies on a missing `.pc` file. Check before spending minutes on a build that cannot finish:

```bash
for p in dbus-1 webkit2gtk-4.1 gtk+-3.0 javascriptcoregtk-4.1; do
  pkg-config --exists "$p" || echo "missing: $p"
done
```

On Debian/Ubuntu the packages are:

```bash
sudo apt install libwebkit2gtk-4.1-dev build-essential curl wget file \
  libxdo-dev libssl-dev libayatana-appindicator3-dev librsvg2-dev \
  libdbus-1-dev pkg-config
```

Fedora and Arch have equivalents under different names; Tauri's prerequisites page is the authority. macOS needs Xcode command line tools, Windows needs the MSVC build tools and WebView2.

This is a `sudo` install, so it is the user's call to make, not something to run on their behalf. Tell them what is missing and let them decide — the rest of the project builds and runs without it, only the desktop target is blocked.

```bash
npx tauri init --ci \
  --app-name "<Display Name>" \
  --window-title "<Display Name>" \
  --frontend-dist ../build \
  --dev-url http://localhost:1420 \
  --before-dev-command "npm run dev" \
  --before-build-command "npm run build"
```

`--ci` is what suppresses the prompts; without it this command waits for answers that will never come. The flag is `--frontend-dist`, not `--dist-dir` — it maps to `frontendDist` in the generated config. If any flag is rejected, read `npx tauri init --help` and use the current name; these CLIs rename flags between majors. Do not fall back to running the command bare and hoping, because that is the hang.

**`tauri init` has no identifier flag.** It writes `"identifier": "com.tauri.dev"` and Tauri will not bundle an app that still carries the placeholder, so set it yourself right after init, to the same value Capacitor uses:

```json
{ "identifier": "com.example.cadence" }
```

This is easy to miss precisely because init appears to have succeeded — every other value you passed is correctly in place.

Then verify `src-tauri/tauri.conf.json` contains:

```json
{
  "build": {
    "frontendDist": "../build",
    "devUrl": "http://localhost:1420",
    "beforeDevCommand": "npm run dev",
    "beforeBuildCommand": "npm run build"
  }
}
```

### 4. Capacitor

```bash
npm run build          # capacitor init wants webDir to exist
npx cap init "<Display Name>" <bundle-id> --web-dir build   # hyphen-free bundle id

# Each platform needs its package installed BEFORE `cap add` can generate it.
npm i @capacitor/android && npx cap add android   # needs JDK + Android SDK
npm i @capacitor/ios     && npx cap add ios       # macOS + Xcode only
```

On iOS, **CocoaPods is not needed to get started**. Capacitor 8 generates a Swift Package Manager project (`ios/App/CapApp-SPM/Package.swift`) and no Podfile, so `cap add ios` succeeds on a machine that has never seen `pod`. It stops being optional the moment you add a plugin that ships no `Package.swift`, and plenty still do not, so on a machine that will grow past the base project it is worth installing anyway: `brew install cocoapods`. Do not install it via `sudo gem install` on modern macOS, where the system Ruby is both ancient and SIP-protected.

What iOS does need is the **active** developer directory pointing at Xcode. `xcode-select -p` returning `/Library/Developer/CommandLineTools` means builds fail even with Xcode installed, and the error mentions missing SDKs rather than the real cause:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

One consequence of the move to SPM catches out anyone following older instructions: **there is no `App.xcworkspace`**. A workspace is a CocoaPods artifact, so most Capacitor build snippets on the web now fail with `'App.xcworkspace' does not exist`. Build the project instead:

```bash
cd ios/App
xcodebuild -scheme App -project App.xcodeproj -configuration Debug \
  -sdk iphonesimulator -destination "generic/platform=iOS Simulator" build
```

`ls ios/App` settles which you have: `App.xcworkspace` means CocoaPods, `CapApp-SPM/` means Swift Package Manager.

**A freshly installed Xcode 26 contains no iOS platform**, and until it is downloaded no iOS build works at all, device or simulator:

```bash
xcodebuild -downloadPlatform iOS      # several GB
```

Nothing about the failure points at this. `xcodebuild -showsdks` still lists iOS SDKs, and the build stops with `Found no destinations for the scheme 'App'`, which reads like a scheme misconfiguration. `xcrun simctl list runtimes` coming back empty is the real tell, and it is what `scripts/preflight.sh ios` checks. Because the download is large and slow, tell the user and let them start it rather than kicking it off for them.

Without the package, `cap add` fails with `Could not find the android platform` — which reads like a missing SDK but is just a missing npm dependency. Install the one you need, not both: `@capacitor/ios` on a Linux machine is dead weight you cannot build with anyway.

Add platforms only where the toolchain exists. Skipping one costs nothing — `cap add` works any time later, and adding it on the machine that can actually build it is the better moment.

In a TypeScript project `cap init` writes **`capacitor.config.ts`**, not the `.json` most documentation shows; it follows the project language. Look for the right one before concluding the command failed.

### 5. Scripts

Add to `package.json`:

```json
{
  "scripts": {
    "tauri": "tauri",
    "desktop": "tauri dev",
    "desktop:build": "tauri build",
    "mobile:sync": "npm run build && npx cap sync",
    "ios": "npm run mobile:sync && npx cap run ios",
    "android": "npm run mobile:sync && npx cap run android"
  }
}
```

`cap sync` copies the web build into the native projects and installs native plugin deps. Every web change needs a re-sync before it shows in a native build — that's the step people forget.

### 6. Gitignore

Append:

```
src-tauri/target/
ios/
android/
.capacitor/
.env
```

`.env` holds the database and storage credentials, so it stays out of git. Commit `.env.example` with the same keys and blank values so the next person knows what to fill in.

Native platform folders are generated; regenerating them is cheaper than resolving merge conflicts in Xcode project files. If the user needs to hand-edit native config, remove the relevant line then.

## Backend: pick one, then Dockerize it

Every piece of the backend runs in Docker, never installed on the host. The reason is reproducibility and cleanup: a teammate cloning the repo should get an identical stack from one command, and tearing it down should leave nothing behind. A host-installed Postgres that someone upgrades six months from now is how "works on my machine" starts.

If `$backend` was given, it has already decided this: go straight to that variant's reference. Otherwise ask, and wait. If the user genuinely has no preference after seeing the choice, Supabase is the one to recommend and say why, but that is a recommendation you offer rather than a default you apply.

**Local Supabase** is the default. One command gives Postgres, an auto-generated REST API, S3-compatible storage, auth, and a table UI. It collapses three of the four pieces below into a single dependency, which is a lot less to wire up and a lot less to break. Read `references/backend-supabase.md`.

**Postgres + API server + MinIO** when the user needs an API shape PostgREST won't give them, wants no vendor coupling, or has to mirror an existing production stack. More moving parts, full control. Read `references/backend-postgres-minio.md`.

Either way, add **Redis**. Supabase ships no cache, and the DIY stack needs one declared explicitly. Both reference files include it.

Read only the file for the variant you picked. They are alternatives, not layers.

### What the browser must never touch

Postgres, Redis, and MinIO credentials belong to server-side code only. A SPA that connects to Redis directly is putting a credential in a bundle anyone can read in devtools, and the browser cannot speak those wire protocols anyway. Everything client-side goes through HTTP: the Supabase client, or your API server.

Supabase's anon key is the deliberate exception, designed to be public and enforced by row-level security. Its `service_role` key is not, and must stay out of anything under `src/` and out of any `VITE_`-prefixed variable, since Vite inlines those into the built bundle.

## Wiring the frontend to it

The API base URL is not one value. Each platform reaches the host differently, and this catches everyone once:

| Target | Base URL |
|---|---|
| Web dev + Tauri desktop | `http://localhost:<port>` |
| iOS simulator | `http://localhost:<port>` |
| Android emulator | `http://10.0.2.2:<port>` |
| Physical device, either OS | `http://<your-LAN-IP>:<port>` |

`10.0.2.2` is the Android emulator's alias for the host machine; `localhost` inside that emulator means the emulator itself, which is why the request fails with nothing in the server log. Resolve it at runtime so one build works everywhere:

`src/lib/api.ts`:

```ts
import { Capacitor } from '@capacitor/core';

const base = import.meta.env.VITE_API_URL ?? 'http://localhost:54321';

export const API_URL =
  Capacitor.getPlatform() === 'android' && base.includes('localhost')
    ? base.replace('localhost', '10.0.2.2')
    : base;
```

**The rewrite above is emulator-only, and nothing at runtime distinguishes an emulator from a real phone.** If `.env` still says `localhost` when you build for a physical device, the resolver quietly turns it into `10.0.2.2`, which means nothing on that phone. The symptom is a build that works in the emulator and fails on hardware with no error. So for a physical device the LAN address has to be in `.env` before the build, not fixed up afterwards.

For a physical device, set `VITE_API_URL` to your LAN IP. Two things then bite in sequence, and both look like the same "it just doesn't connect":

**The URL the tooling prints is not the URL the phone needs.** `supabase start` reports `http://127.0.0.1:54321`, and copying that into `.env` is the most common way this fails — `127.0.0.1` on the phone means *the phone*, so it never leaves the device. Substitute the host's LAN address; nothing needs reconfiguring, because local Supabase already listens on all interfaces.

A server you wrote yourself is the case that can genuinely be bound to loopback. Check rather than assume:

```bash
ss -ltn | grep <port>      # 0.0.0.0:<port> is reachable from the LAN; 127.0.0.1:<port> is not
```

**`VITE_` variables are baked in at build time, not read at runtime.** Editing `.env` changes nothing until you rebuild, and a native shell additionally needs the fresh bundle copied into it:

```bash
npm run build && npx cap sync
```

Skipping that is why people change the URL, see no difference, and conclude the URL was wrong. It usually wasn't; the device was still running the previous bundle.

Reach for `adb logcat` early here rather than reasoning from the outside. The WebView reports the real reason under `Capacitor/Console`, and it is the only place any of this is visible: the device shows nothing, and the server log stays empty because the request was stopped before it left the phone.

What makes this genuinely hard to debug is that all three causes — wrong URL, stale bundle, loopback bind — produce the identical symptom: the request never arrives and the server log stays empty. There is no error to read, so guessing is unproductive. Check them in a fixed order instead, cheapest first: confirm the bind with `ss`, rebuild and sync, then verify the LAN IP is reachable from the phone's browser before blaming the app at all. If the phone's browser can't load the URL either, the problem is the network or the firewall, not your code.

**Android blocks cleartext HTTP, and Capacitor does not exempt it for you.** A freshly generated project has no `usesCleartextTraffic` and no `networkSecurityConfig` anywhere, so every `http://` request fails on device with nothing useful in the log. Add a debug-variant overlay rather than editing the main manifest, so the exemption cannot reach a release build:

`android/app/src/debug/AndroidManifest.xml`

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
    <application
        android:usesCleartextTraffic="true"
        tools:replace="android:usesCleartextTraffic" />
</manifest>
```

Production wants HTTPS, not a wider exemption.

**That alone is still not enough, and the second blocker is the one that wastes an evening.** Capacitor serves the app from `https://localhost` on Android, and a page loaded over HTTPS may not fetch `http://` - the WebView rejects it as mixed content. This is a separate mechanism from cleartext: the request never reaches the network layer, so `usesCleartextTraffic` has no bearing on it. The giveaway is in `adb logcat`:

```
E Capacitor/Console: Mixed Content: The page at 'https://localhost/' was loaded
over HTTPS, but requested an insecure resource 'http://192.168.1.42:54321/...'.
This request has been blocked
```

Put the app on the same scheme as the API while the API is plain http:

```ts
// capacitor.config.ts
server: {
  androidScheme: 'http',
  cleartext: true
}
```

`androidScheme` sits under `server`, not under `android`. Putting it in the wrong place fails silently: `cap sync` copies the config through without complaint, the app still loads from `https://localhost`, and the mixed-content error is unchanged. Confirm the value landed by reading what actually shipped, `android/app/src/main/assets/capacitor.config.json`, rather than trusting the source file.

Reinstalling with `adb install -r` keeps app data, and the WebView can serve the previous origin from cache. Run `adb shell pm clear <appId>` when a scheme change appears not to take.

Switch it back to `https` once the API has TLS. Changing the scheme changes the WebView's origin, so anything the app kept in `localStorage` or IndexedDB under the old origin is no longer visible - harmless on day one, worth knowing later.

The alternative is to stop using the WebView's `fetch` at all: `CapacitorHttp` routes requests through native code, where neither mixed content nor CORS applies. That is the better answer for a production app talking to several hosts, and a bigger change than a dev loop needs.

**iOS does not have this problem, and the reason is worth knowing.** Capacitor serves iOS from `capacitor://localhost`, which is not an HTTPS origin, so no mixed-content rule fires and a plain `http://` API works with no configuration at all. Verified in the simulator against a `http://` Supabase on another machine: no `NSAppTransportSecurity` keys in `Info.plist`, no `iosScheme` override, and the fetch succeeded. The platforms differ in their default scheme, not in how strict they are, so do not go adding ATS exemptions on iOS to fix a problem that only exists on Android.

## The iOS layout detail nobody remembers

An app that looks right in a browser will have its header under the Dynamic Island on a modern iPhone, because a WebView fills the whole screen. Two things are needed, and one without the other does nothing:

```html
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
```

```css
padding: calc(5rem + env(safe-area-inset-top)) calc(1.5rem + env(safe-area-inset-right))
         calc(6rem + env(safe-area-inset-bottom)) calc(1.5rem + env(safe-area-inset-left));
```

`env()` reports zero without `viewport-fit=cover`, and it resolves to zero on every platform that has no inset, so the same CSS is correct on web, desktop and Android.

## When the ports are already taken

Every service here claims a well-known port, and anyone who runs more than one project locally will eventually collide: 54321-54323 for Supabase, 5432 Postgres, 6379 Redis, 9000/9001 MinIO, 1420 the dev server. A second Supabase instance is the usual culprit, because the CLI uses the same ports for every project on the machine.

Check before starting rather than reading the failure afterwards:

```bash
ss -ltn | grep -E ':(1420|5432|6379|9000|9001|5432[1-3])\b' || echo "all clear"
```

Two different fixes, and picking the wrong one wastes time. If it is **your own other project**, stop that one (`npx supabase stop` in its directory, or `docker compose down` there) — running two local Supabase stacks at once is rarely what anyone wants. If it is **something you need to keep running**, remap this project instead: change the host side of the compose port mappings (`"5433:5432"` leaves the container's port alone), or for Supabase set different ports in `supabase/config.toml`.

Whatever you remap, the app's `VITE_` URL has to follow, and so does `devUrl` in `tauri.conf.json` if you moved 1420. A remapped port with a stale URL looks exactly like a service that failed to start.

## Verify before handing back

Run these — a scaffold that "looks right" but doesn't build is worse than no scaffold:

```bash
npm run build && ls build/index.html
docker compose ps          # every service Up; Supabase: npx supabase status
curl -fsS http://localhost:54321/rest/v1/ >/dev/null && echo "api reachable"
```

A successful build ends by naming the adapter it used:

```
> Using @sveltejs/adapter-static
  Wrote site to "build"
```

If that line says `adapter-auto`, the static adapter never got wired in and the native targets will not load — fix it before going further.

Adjust the port to your variant (Supabase 54321, custom API 3000). A container in `Restarting` is the usual sign the API booted before Postgres was ready; the healthcheck conditions in the reference files are what prevent that.

Then confirm each target the preflight cleared actually starts — `npm run desktop` for desktop, `npm run android` for Android. Re-run `scripts/preflight.sh` at the end if anything was installed mid-way.

State the result per target, not as one verdict. "Web and Android build, desktop is blocked on libwebkit2gtk-4.1, iOS needs a Mac" is useful. "Set up successfully" is not, and is what someone writes when they have not checked.

## Tell the user the overlap

Tauri v2 targets mobile too. Running Tauri *and* Capacitor means two native toolchains for the same platforms. Worth one sentence when you hand the scaffold back:

> Both are set up as asked. Tauri v2 can also build iOS/Android — if you don't specifically need Capacitor's plugin ecosystem (Camera, Push, native SDK wrappers), dropping Capacitor removes a whole build path.

Say it once, then respect whatever they choose. If they keep both, the split that works is: Capacitor for mobile, Tauri for desktop, same `build/` output feeding both.

## Common breakages

| Symptom | Cause |
|---|---|
| White screen in native shell | SSR still on, or `webDir`/`frontendDist` pointing at the wrong folder |
| Native build shows stale UI | Forgot `npx cap sync` after `npm run build` |
| Tauri dev can't reach frontend | Vite port drifted off 1420 — check `strictPort` |
| `cap init` fails on webDir | Run `npm run build` first; the folder must exist |
| API works in browser, fails on Android emulator | `localhost` needs to be `10.0.2.2` |
| API works in emulator, fails on a real phone | Backend bound to `127.0.0.1`, not `0.0.0.0` |
| Changed the API URL, device behaves identically | `VITE_` vars are build-time; rebuild and `cap sync` |
| Every fetch fails on a real phone, works in emulator | `.env` still said `localhost`, so it became `10.0.2.2` |
| Every fetch fails on device, no error in any log | Cleartext HTTP blocked; add the debug manifest overlay |
| `adb logcat` shows "Mixed Content ... has been blocked" | App is on `https://localhost`; set `androidScheme: 'http'` |
| A scaffold command produces no output and never returns | It is waiting on a prompt; re-run it with the non-interactive flags |
| `cap init` rejects the App ID | Hyphen or a segment not starting with a letter; strip hyphens |
| `tauri build` refuses to bundle | `identifier` still `com.tauri.dev`; set it in `tauri.conf.json` |
| `tauri dev` compiles a while, then panics on a `.pc` file | Missing Linux system libs; see the prerequisite check in step 3 |
| API container restart-loops | Started before Postgres was healthy; use the healthcheck conditions |
| Supabase queries return empty, no error | Row-level security is on and no policy matches; write the policy |
| Routes 404 on refresh in native | Missing `fallback: 'index.html'` in the adapter |

## After the scaffold

Now let the user describe their project. Build features into `src/routes/` and `src/lib/` as normal Svelte, and put anything needing a database, a secret, or the cache behind the API. The platform plumbing and the data layer are both done and shouldn't need revisiting.

The rest of the plugin picks up from here:

| Skill | Use it for |
|---|---|
| `/multi-platform:apptest` | Testing a change. Playwright against the web build: fast, free, and right for anything that is not a native API. Reach for this by default. |
| `/multi-platform:build` | Native artifacts for every platform, built on GitHub Actions runners that already have the SDKs and Xcode. |
| `/multi-platform:build-test` | Build plus emulator and simulator runs. Slow, and costly on a private repo, so it belongs before a release rather than on every push. |

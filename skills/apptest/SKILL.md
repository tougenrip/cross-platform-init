---
name: apptest
argument-hint: "[spec-file-or-pattern]"
description: >
  Runs the app's web build against Playwright: fast, free, and the right default
  for checking that a change works. Use this whenever someone asks to test the
  app, verify a feature, check a regression, or confirm something still works
  after an edit, unless the thing under test is specifically a native
  capability. Runs locally and in cloud sessions alike. It exercises the same
  Svelte code the native shells ship, so most logic and UI bugs surface here at
  a fraction of the cost of a native build.
---

# Test the app with Playwright

This is the cheap test and it should be the habitual one. Capacitor and Tauri
both wrap the same static bundle, so anything that is not touching a native API
behaves the same in a browser as it does on a device. A run takes seconds,
costs nothing, and needs no signing, emulator or runner.

Reach for `/multi-platform:build-test` only when the thing you need to check
genuinely cannot happen in a browser.

## Arguments

`/multi-platform:apptest [spec-file-or-pattern]`

`$ARGUMENTS` narrows the run, and is empty when omitted:

- **Empty** runs the whole suite. It is fast enough that this is usually right.
- **A path** runs one file: `apptest e2e/todo.spec.ts`.
- **A pattern** runs matching titles: `apptest --grep "due date"`.

While iterating on one failure, narrow to it. A tight loop on a single spec is
worth more than a full suite you stop reading.

## What this cannot tell you

Be honest about the boundary rather than implying broader coverage:

- Anything behind a Capacitor or Tauri plugin: camera, filesystem, push,
  biometrics, share sheets, deep links, native auth, secure storage.
- Platform networking behaviour. The Android WebView blocking a plain `http://`
  call as mixed content, or an emulator needing `10.0.2.2`, cannot reproduce in
  a desktop browser.
- Anything about the shell itself: window sizing, permissions prompts, app
  lifecycle, background behaviour.
- WebView engine differences. Playwright's WebKit is a reasonable stand-in for
  iOS, not a guarantee.

Everything else, which is most of an app, tests here.

## Setting it up

Playwright may already be present if the project was scaffolded with the
`playwright` add-on. Check before installing:

```bash
npx playwright --version 2>/dev/null || npm i -D @playwright/test
npx playwright install --with-deps chromium
```

Install the browsers you will actually assert against. `chromium` alone is
usually right for a first pass; add `webkit` when iOS rendering matters.

A config that matches this stack, at `playwright.config.ts`:

```ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: 'e2e',
  // The app is a static SPA, so serve the real build rather than the dev
  // server: that is the artifact the native shells actually ship.
  webServer: {
    command: 'npm run build && npx vite preview --port 4173 --strictPort',
    url: 'http://localhost:4173',
    reuseExistingServer: !process.env.CI
  },
  use: { baseURL: 'http://localhost:4173', trace: 'on-first-retry' },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }]
});
```

Testing the build rather than `npm run dev` matters here: the SPA fallback,
the adapter output and the inlined `VITE_` values are all things that only
exist after a build, and all three have broken this stack before.

## Writing the tests

Put specs in `e2e/`. Drive the app the way a person would and assert on what
they would see, not on implementation detail:

```ts
import { test, expect } from '@playwright/test';

test('adds a task and it survives a reload', async ({ page }) => {
  await page.goto('/');
  await page.getByLabel('Task title').fill('Renew passport');
  await page.getByRole('button', { name: 'Add' }).click();
  await expect(page.getByText('Renew passport')).toBeVisible();

  await page.reload();
  await expect(page.getByText('Renew passport')).toBeVisible();
});
```

Prefer `getByRole` and `getByLabel` over CSS selectors. They survive restyling,
and they fail when the app becomes unusable with a keyboard or screen reader,
which a class selector never notices.

## If the app talks to a backend

The tests need something to talk to. Two honest options, and which one you want
depends on what you are testing:

**Against the real local stack.** Start Supabase or the compose stack first and
let the tests hit it. This catches schema and query mistakes, and it is what you
want before a release. It needs the backend running and leaves data behind, so
reset between runs or write specs that tolerate existing rows.

**Against intercepted routes.** `page.route()` lets you answer network calls
with fixtures, so the suite runs anywhere with no database at all. This is
faster and far more stable in CI, and it is the right default for testing UI
behaviour. It tells you nothing about whether your queries are correct.

Use the second for most specs and a small number of the first for the paths that
would hurt if the schema drifted.

## Running

```bash
npx playwright test                  # all specs
npx playwright test --ui             # pick through them interactively
npx playwright test --reporter=list  # CI-friendly output
npx playwright show-report           # after a failure
```

On a failing run, read the trace rather than guessing: `trace: 'on-first-retry'`
records the DOM, network and console at each step, which is usually faster than
re-running with extra logging.

## In CI

`assets/apptest.yml` is a workflow that runs this on every push. It uses an
Ubuntu runner, which is free for public repositories and the cheapest runner for
private ones. Install it if the repository has no web test workflow yet:

```bash
mkdir -p .github/workflows
cp ${CLAUDE_PLUGIN_ROOT}/skills/apptest/assets/apptest.yml .github/workflows/
```

This also runs unchanged inside a cloud session: the sandbox is Ubuntu with
network access to npm, so the browsers install and the suite runs exactly as it
does locally.

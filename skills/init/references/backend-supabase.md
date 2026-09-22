# Backend variant: local Supabase

One command gives you Postgres, an auto-generated REST API, S3-compatible storage, auth, and a web UI, all in Docker. Pick this unless the user needs a custom API shape or wants no vendor coupling.

## Requirements

Docker must be running before anything else. `supabase start` pulls and runs about a dozen containers on first use, so the first run takes a few minutes. Say so rather than letting it look hung.

## Setup

```bash
npm i -D supabase@latest
npx supabase init          # creates supabase/ with config.toml
npx supabase start         # boots the stack, prints URLs and keys
```

`supabase start` prints an `API URL`, `DB URL`, `Studio URL`, `anon key`, and `service_role key`. Capture them; you need the API URL and anon key for the frontend.

Default local ports:

| Service | Port | Use |
|---|---|---|
| API (PostgREST + auth + storage) | 54321 | what the app talks to |
| Postgres | 54322 | direct SQL, migrations |
| Studio | 54323 | browser UI for tables and data |

## Redis alongside it

Supabase ships no cache, so add one. The Supabase CLI manages its own containers, so keep yours in a separate compose file rather than trying to edit theirs.

`docker-compose.yml`:

```yaml
services:
  redis:
    image: redis:8-alpine
    restart: unless-stopped
    ports: ["6379:6379"]
    command: ["redis-server", "--save", "60", "1", "--loglevel", "warning"]
    volumes: [redis-data:/data]
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5

volumes:
  redis-data:
```

```bash
docker compose up -d
```

Reach it from the host at `redis://localhost:6379`.

Important: a browser or WebView cannot speak the Redis protocol, and it must never try. Redis here is for server-side code, which means Supabase Edge Functions or your own small service. If the user asks the SPA to "use Redis directly", explain that the cache sits behind an API, and that putting a Redis credential in a client bundle hands it to anyone who opens devtools.

## Client wiring

```bash
npm i @supabase/supabase-js
```

`.env` (gitignore this):

```
VITE_SUPABASE_URL=http://localhost:54321
VITE_SUPABASE_ANON_KEY=<anon key printed by supabase start>
```

`.env.example` (commit this, with the values blanked) so the next person knows what to fill in.

`src/lib/supabase.ts`:

```ts
import { createClient } from '@supabase/supabase-js';

export const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_ANON_KEY
);
```

Current CLI versions print two key pairs and the naming has moved, which causes real confusion when docs and output disagree:

| Printed as | Older name | Safe in a client bundle? |
|---|---|---|
| `PUBLISHABLE_KEY` (`sb_publishable_…`) | `ANON_KEY` | Yes, that is its purpose |
| `SECRET_KEY` (`sb_secret_…`) | `SERVICE_ROLE_KEY` | **No** |

Either name works against a local stack; use whichever your CLI emits. The distinction that matters is the second row: the secret/service-role key bypasses row-level security entirely. Keep it out of any file under `src/`, out of `VITE_`-prefixed variables (Vite inlines those into the bundle), and out of git.

## Reaching it from a physical device

Local Supabase already listens on all interfaces — verified: `ss -ltn` shows `0.0.0.0:54321`, and the host's LAN address answers with a 200. There is no bind to widen and no config key for one, so ignore any advice telling you to change it.

The actual trap is the URL. `supabase start` prints:

```
API_URL: http://127.0.0.1:54321
```

That address is correct for the host and useless everywhere else: on a phone, `127.0.0.1` is the phone. Copy-pasting it into `.env` is the single most common cause of "it works in the browser but not on my device". Substitute the host's LAN address:

```bash
ip route get 1.1.1.1 | grep -oP 'src \K\S+'    # prints the host's LAN IP
```

```
VITE_SUPABASE_URL=http://192.168.1.42:54321      # not 127.0.0.1
```

Then rebuild, because `VITE_` values are inlined at build time: `npm run build && npx cap sync`.

If it still fails after that, the remaining causes are outside Supabase: the phone is on a different network or the router has client isolation on, or the host firewall drops inbound on that port. Test by opening the URL in the phone's own browser — if that fails too, the app is not involved and you are debugging the network.

## Schema changes

Use migrations rather than clicking in Studio, so the schema is reproducible on another machine:

```bash
npx supabase migration new <name>     # creates supabase/migrations/<ts>_<name>.sql
# write SQL in that file
npx supabase db reset                 # rebuilds local db and replays all migrations
```

`db reset` drops local data. That is fine in development and destructive anywhere else, so never suggest it against a linked remote project.

Row-level security is on by default for new tables, which means queries return empty until a policy exists. That surprises people and reads as "my data disappeared". It is the safe default: write the policy rather than turning RLS off.

## Teardown

```bash
npx supabase stop        # stops containers, keeps data
npx supabase stop --no-backup   # stops and discards local data
docker compose down      # stops redis; add -v to wipe its volume
```

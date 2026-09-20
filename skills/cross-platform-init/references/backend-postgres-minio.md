# Backend variant: Postgres + API server + MinIO

Assemble the pieces yourself. Pick this when the user needs an API shape that PostgREST will not give them, wants no vendor coupling, or has to mirror an existing production stack.

Everything runs in Docker. Do not install Postgres, Redis, or MinIO on the host: a teammate cloning the repo should get the same stack from one command, and `docker compose down -v` should leave no trace.

## Layout

```
docker-compose.yml
.env                 # gitignored, real values
.env.example         # committed, blank values
server/              # the API service
  Dockerfile
  src/index.ts
db/migrations/       # plain .sql files
```

## docker-compose.yml

```yaml
services:
  postgres:
    image: postgres:17-alpine
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    ports: ["5432:5432"]
    volumes: [pg-data:/var/lib/postgresql/data]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}"]
      interval: 5s
      timeout: 3s
      retries: 10

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

  minio:
    image: quay.io/minio/minio:latest
    restart: unless-stopped
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD}
    ports: ["9000:9000", "9001:9001"]
    volumes: [minio-data:/data]
    healthcheck:
      test: ["CMD", "mc", "ready", "local"]
      interval: 5s
      timeout: 3s
      retries: 10

  # Creates the bucket once, then exits. Without this the API's first
  # upload fails against a bucket nobody made.
  minio-init:
    image: quay.io/minio/mc:latest
    depends_on:
      minio: {condition: service_healthy}
    entrypoint: >
      /bin/sh -c "
      mc alias set local http://minio:9000 $${MINIO_ROOT_USER} $${MINIO_ROOT_PASSWORD} &&
      mc mb --ignore-existing local/$${MINIO_BUCKET} &&
      echo 'bucket ready'"
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD}
      MINIO_BUCKET: ${MINIO_BUCKET}

  api:
    build: ./server
    restart: unless-stopped
    ports: ["3000:3000"]
    environment:
      DATABASE_URL: postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}
      REDIS_URL: redis://redis:6379
      S3_ENDPOINT: http://minio:9000
      S3_BUCKET: ${MINIO_BUCKET}
      S3_ACCESS_KEY: ${MINIO_ROOT_USER}
      S3_SECRET_KEY: ${MINIO_ROOT_PASSWORD}
    depends_on:
      postgres: {condition: service_healthy}
      redis: {condition: service_healthy}
      minio: {condition: service_healthy}

volumes:
  pg-data:
  redis-data:
  minio-data:
```

MinIO is pulled from **quay.io, not Docker Hub**. The `minio/minio` path on Hub no longer serves these images, and the failure is misleading: `docker compose up` reports `unauthorized: authentication required`, which reads like a credentials problem and sends people looking for a login they do not need. The image simply is not there any more.

Two details that prevent the most common failures. `depends_on` with `condition: service_healthy` makes the API wait for a database that actually accepts connections, instead of crash-looping against one that has merely started. And `$${VAR}` inside a compose `command` or `healthcheck` escapes the dollar so the container's shell expands it, not compose.

Note the split between host and container addresses: from inside the network, services reach each other by service name (`postgres:5432`, `minio:9000`). From your machine, use `localhost` with the published port. Mixing these up produces `ENOTFOUND postgres` in one direction and connection refused in the other.

## .env

```
POSTGRES_USER=app
POSTGRES_PASSWORD=devpassword
POSTGRES_DB=app
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=devpassword123
MINIO_BUCKET=uploads
```

Commit `.env.example` with the keys and empty values; never commit `.env`. These are throwaway development credentials and should look like it. If the user talks about deploying, say plainly that these values need replacing and belong in the host's secret store, not in the repo.

## API server

Any HTTP framework works. Keep the container small and give it a health endpoint, because the frontend and your own debugging both need a cheap way to ask whether the stack is up.

`server/Dockerfile`:

```dockerfile
FROM node:22-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY . .
EXPOSE 3000
CMD ["node", "--experimental-strip-types", "src/index.ts"]
```

The API needs permissive CORS in development, since the SPA runs on port 1420 and native WebViews present origins like `capacitor://localhost` and `tauri://localhost`. Allow those explicitly in development and tighten for production rather than shipping `*`.

## Migrations

Plain SQL files in `db/migrations/`, applied in filename order. Apply them with a one-off container so no Postgres client is needed on the host:

```bash
docker compose exec -T postgres psql -U app -d app < db/migrations/001_init.sql
```

Reach for a migration tool once ordering and rollback start to matter. Until then this is enough and has no dependencies.

## Teardown

```bash
docker compose down       # stop, keep data
docker compose down -v    # stop and delete all volumes, including the database
```

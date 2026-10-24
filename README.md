# Authelia OCI image

Nix-built x86_64 Linux image using the pinned Nixpkgs Authelia 4.39.28 package and `dockerTools`.

## Build

```sh
nix flake check
nix build .#image
```

The OCI archive is produced locally; this repository does not publish or deploy it.

## Upstream Dockerfile baseline

The version-matched upstream [Dockerfile](https://raw.githubusercontent.com/authelia/authelia/v4.39.28/Dockerfile) uses an `authelia/base` image, runs `/app/entrypoint.sh`, exposes TCP 9091, and checks `/api/health` with its healthcheck script. The entrypoint applies `UMASK`, permits command overrides, and when run as root recursively chowns `/config` before dropping to `PUID:PGID`.

This image keeps the app path, command override behavior, optional `UMASK`, port, config path, and HTTP health check. It runs directly as fixed UID/GID `10001:10001`, so it omits root-mode `PUID/PGID` switching and recursive ownership repair. Ensure the mounted configuration and any storage paths in it are readable/writable by that identity.

## Runtime contract

- Entrypoint: `/app/entrypoint.sh`; default command: `--config /config/configuration.yml`.
- Mount configuration and secret files at `/config`; the image contains no user config or secrets.
- TCP port: 9091; health endpoint: `/api/health`.
- `/tmp` is prepared for temporary files. For read-only-root operation, mount it as tmpfs.
- The health check defaults to HTTP on localhost:9091 and supports the upstream `X_AUTHELIA_HEALTHCHECK_*` overrides.

Authelia's official deployment guide recommends running as a configured non-root user and passing secrets through files: https://www.authelia.com/integration/deployment/docker/

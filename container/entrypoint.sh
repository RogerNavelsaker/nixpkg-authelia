#!/bin/sh
[ -z "${UMASK:-}" ] || umask "$UMASK"

if [ -n "${1:-}" ] && [ "$1" != "--config" ]; then
  exec "$@"
fi

exec @authelia@ "$@"

#!/bin/sh

if [ -z "${X_AUTHELIA_HEALTHCHECK:-}" ]; then
  exit 0
fi

: "${X_AUTHELIA_HEALTHCHECK_SCHEME:=http}"
: "${X_AUTHELIA_HEALTHCHECK_HOST:=localhost}"
: "${X_AUTHELIA_HEALTHCHECK_PORT:=9091}"
: "${X_AUTHELIA_HEALTHCHECK_PATH:=}"

exec @wget@ --quiet --no-check-certificate --tries=1 --spider \
  "${X_AUTHELIA_HEALTHCHECK_SCHEME}://${X_AUTHELIA_HEALTHCHECK_HOST}:${X_AUTHELIA_HEALTHCHECK_PORT}${X_AUTHELIA_HEALTHCHECK_PATH}/api/health"

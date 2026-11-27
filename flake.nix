{
  description = "Authelia OCI image built with Nix dockerTools";
  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://rogernavelsaker.cachix.org"
      "https://nacosolutions.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "rogernavelsaker.cachix.org-1:n1DtzMNhA9Rz4Kg3xlXOi/KceULu8VrMbs9WXyMFQNQ="
      "nacosolutions.cachix.org-1:JzCiW2CLcuLXtwOVAg3SlSK/kpqWbfSFEVenyKVUlug="
    ];
  };

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/02c087f3fe673c9e317f206a627cb6b910336dbe";

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      authelia = pkgs.authelia;
      version = "4.39.28";
      fakeNss = pkgs.dockerTools.fakeNss.override {
        extraPasswdLines = [ "authelia:x:10001:10001:Authelia:/config:/noshell" ];
        extraGroupLines = [ "authelia:x:10001:" ];
      };
      scripts = pkgs.runCommand "authelia-container-scripts" { } ''
        mkdir -p "$out/app"
        substitute ${./container/entrypoint.sh} "$out/app/entrypoint.sh" \
          --replace-fail @authelia@ ${authelia}/bin/authelia
        substitute ${./container/healthcheck.sh} "$out/app/healthcheck.sh" \
          --replace-fail @wget@ ${pkgs.wget}/bin/wget
        chmod 0555 "$out/app/entrypoint.sh" "$out/app/healthcheck.sh"
      '';
      runtimeCheck = pkgs.runCommand "authelia-runtime-contract" {
        nativeBuildInputs = [ pkgs.gnugrep ];
      } ''
        ${authelia}/bin/authelia --version 2>&1 | grep -F "v${version}-nixpkgs"
        test -x ${scripts}/app/entrypoint.sh
        test -x ${scripts}/app/healthcheck.sh
        grep -F "authelia:x:10001:10001:" ${fakeNss}/etc/passwd
        grep -F "authelia:x:10001:" ${fakeNss}/etc/group
        touch "$out"
      '';
      image = assert authelia.version == version;
        pkgs.dockerTools.buildLayeredImage {
          name = "authelia";
          tag = version;
          contents = [
            authelia
            scripts
            fakeNss
            pkgs.cacert
            pkgs.tzdata
            pkgs.dash
            pkgs.wget
          ];

          config = {
            User = "10001:10001";
            WorkingDir = "/app";
            Entrypoint = [ "/app/entrypoint.sh" ];
            Cmd = [ "--config" "/config/configuration.yml" ];
            Env = [
              "PATH=${authelia}/bin:${pkgs.wget}/bin"
              "HOME=/tmp"
              "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
              "X_AUTHELIA_CONFIG=/config/configuration.yml"
              "X_AUTHELIA_HEALTHCHECK=true"
              "X_AUTHELIA_HEALTHCHECK_SCHEME=http"
              "X_AUTHELIA_HEALTHCHECK_HOST=localhost"
              "X_AUTHELIA_HEALTHCHECK_PORT=9091"
              "X_AUTHELIA_HEALTHCHECK_PATH="
              "TZDIR=${pkgs.tzdata}/share/zoneinfo"
            ];
            ExposedPorts = { "9091/tcp" = { }; };
            Volumes = { "/config" = { }; };
            Healthcheck = {
              Test = [ "CMD" "/app/healthcheck.sh" ];
              Interval = 30000000000;
              Timeout = 3000000000;
              StartPeriod = 60000000000;
              Retries = 3;
            };
            Labels = {
              "org.opencontainers.image.title" = "Authelia";
              "org.opencontainers.image.version" = version;
              "org.opencontainers.image.licenses" = "Apache-2.0";
              "org.opencontainers.image.source" = "https://github.com/authelia/authelia";
              "org.opencontainers.image.description" = "Nix-built Authelia authentication server image";
            };
          };

          fakeRootCommands = ''
            mkdir -p ./app ./bin ./config ./tmp
            ln -sfn ${scripts}/app/entrypoint.sh ./app/entrypoint.sh
            ln -sfn ${scripts}/app/healthcheck.sh ./app/healthcheck.sh
            ln -sfn ${pkgs.dash}/bin/dash ./bin/sh
            chown -R 10001:10001 ./config
            chmod 0750 ./config
            chmod 1777 ./tmp
          '';
        };
    in {
      packages.${system} = {
        inherit image;
        default = image;
      };
      checks.${system} = {
        inherit image;
        runtime-contract = runtimeCheck;
      };
    };
}

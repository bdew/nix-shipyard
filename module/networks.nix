{
  lib,
  config,
  options,
  ...
}:
let
  helpers = import ./helpers.nix { inherit lib; };

  networkOptions =
    { name, ... }:
    {
      options = {
        serviceName = lib.mkOption {
          type = lib.types.str;
          default = "docker-network-${name}";
          defaultText = "docker-network-<name>";
          description = "Systemd service name that manages the network";
        };

        options = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.either lib.types.str (lib.types.either lib.types.bool (lib.types.listOf lib.types.str))
          );
          default = { };
          description = "Options that will be passed to `docker network create`";
        };

        labels = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = "Labels to attach to the network at runtime.";
          example = lib.literalExpression ''
            {
              "foo" = "bar";
            }
          '';
        };

        driverOptions = lib.mkOption {
          type = lib.types.nullOr (lib.types.attrsOf lib.types.str);
          default = null;
          description = "Driver options that will be passed to `docker network create -o`";
        };

        serviceOptions = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          description = "systemd service options that will be merged into service definition for the network";
        };
      };
    };

  mkNetworkService =
    name: cfg:
    lib.mkMerge [
      {
        path = [ config.virtualisation.docker.package ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        requires = [ "docker.service" ];
        after = [ "docker.service" ];
        script = lib.concatStringsSep " " (
          [
            "docker network inspect ${lib.escapeShellArg name} || docker network create ${lib.escapeShellArg name}"
          ]
          ++ (helpers.mkDashDashOpts cfg.options)
          ++ (lib.optional (cfg.driverOptions != null) "-o ${helpers.mkKvOpts cfg.driverOptions}")
          ++ (lib.mapAttrsToList (k: v: "--label ${lib.escapeShellArg k}=${lib.escapeShellArg v}") cfg.labels)
        );
        preStop = "docker network rm -f ${lib.escapeShellArg name}";
      }
      cfg.serviceOptions
    ];

in
{
  options = {
    docker.networks = lib.mkOption {
      default = { };
      type = lib.types.attrsOf (lib.types.submodule networkOptions);
      description = "Docker network definitions";
    };
  };
  config = {
    systemd.services = lib.mapAttrs' (
      n: v: lib.nameValuePair v.serviceName (mkNetworkService n v)
    ) config.docker.networks;
  };
}

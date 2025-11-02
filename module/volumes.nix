{
  lib,
  config,
  options,
  ...
}:
let
  helpers = import ./helpers.nix { inherit lib; };

  volumeOptions =
    { name, ... }:
    {
      options = {
        serviceName = lib.mkOption {
          type = lib.types.str;
          default = "docker-volume-${name}";
          defaultText = "docker-volume-<name>";
          description = "Systemd service name that manages the volume";
        };

        options = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.either lib.types.str (lib.types.either lib.types.bool (lib.types.listOf lib.types.str))
          );
          default = { };
          description = "Options that will be passed to `docker volume create`";
        };

        labels = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = "Labels to attach to the volume at runtime.";
          example = lib.literalExpression ''
            {
              "foo" = "bar";
            }
          '';
        };

        driverOptions = lib.mkOption {
          type = lib.types.nullOr (lib.types.attrsOf lib.types.str);
          default = null;
          description = "Driver options that will be passed to `docker volume create -o`";
        };

        serviceOptions = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          description = "systemd service options that will be merged into service definition for the volume";
        };
      };
    };

  mkVolumeService =
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
            "docker volume inspect ${lib.escapeShellArg name} || docker volume create ${lib.escapeShellArg name}"
          ]
          ++ (helpers.mkDashDashOpts cfg.options)
          ++ (lib.optional (cfg.driverOptions != null) "-o ${helpers.mkKvOpts cfg.driverOptions}")
          ++ (lib.mapAttrsToList (k: v: "--label ${lib.escapeShellArg k}=${lib.escapeShellArg v}") cfg.labels)
        );
      }
      cfg.serviceOptions
    ];

in
{
  options = {
    docker.volumes = lib.mkOption {
      default = { };
      type = lib.types.attrsOf (lib.types.submodule volumeOptions);
      description = "Docker volume definitions";
    };
  };
  config = {
    systemd.services = lib.mapAttrs' (
      n: v: lib.nameValuePair v.serviceName (mkVolumeService n v)
    ) config.docker.volumes;
  };
}

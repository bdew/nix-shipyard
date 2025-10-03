{
  lib,
  config,
  options,
  ...
}:
let
  helpers = import ./helpers.nix { inherit lib; };

  passThroughOptions = [
    "image"
    "imageFile"
    "imageStream"
    "login"
    "cmd"
    "labels"
    "entrypoint"
    "environment"
    "environmentFiles"
    "log-driver"
    "ports"
    "user"
    "workdir"
    "dependsOn"
    "hostname"
    "preRunExtraOptions"
    "autoStart"
    "pull"
    "capabilities"
    "devices"
    "privileged"
    "autoRemoveOnStop"
  ];

  containerOptions =
    { name, ... }:
    {
      options = {
        serviceName = lib.mkOption {
          type = lib.types.str;
          default = "docker-${name}";
          defaultText = "docker-<name>";
          description = "Systemd service name that manages the container";
        };

        image = lib.mkOption {
          type = lib.types.str;
          description = "OCI image to run.";
          example = "library/hello-world";
        };

        imageFile = lib.mkOption {
          type = lib.types.nullOr lib.types.package;
          default = null;
          description = ''
            Path to an image file to load before running the image. This can
            be used to bypass pulling the image from the registry.

            The `image` attribute must match the name and
            tag of the image contained in this file, as they will be used to
            run the container with that image. If they do not match, the
            image will be pulled from the registry as usual.
          '';
          example = lib.literalExpression "pkgs.dockerTools.buildImage {...};";
        };

        imageStream = lib.mkOption {
          type = lib.types.nullOr lib.types.package;
          default = null;
          description = ''
            Path to a script that streams the desired image on standard output.

            This option is mainly intended for use with
            `pkgs.dockerTools.streamLayeredImage` so that the intermediate
            image archive does not need to be stored in the Nix store.  For
            larger images this optimization can significantly reduce Nix store
            churn compared to using the `imageFile` option, because you don't
            have to store a new copy of the image archive in the Nix store
            every time you change the image.  Instead, if you stream the image
            then you only need to build and store the layers that differ from
            the previous image.
          '';
          example = lib.literalExpression "pkgs.dockerTools.streamLayeredImage {...};";
        };

        login = {

          username = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Username for login.";
          };

          passwordFile = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Path to file containing password.";
            example = "/etc/nixos/dockerhub-password.txt";
          };

          registry = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Registry where to login to.";
            example = "https://docker.pkg.github.com";
          };

        };

        cmd = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Commandline arguments to pass to the image's entrypoint.";
          example = lib.literalExpression ''
            ["--port=9000"]
          '';
        };

        labels = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = "Labels to attach to the container at runtime.";
          example = lib.literalExpression ''
            {
              "traefik.https.routers.example.rule" = "Host(`example.container`)";
            }
          '';
        };

        entrypoint = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          description = "Override the default entrypoint of the image.";
          default = null;
          example = "/bin/my-app";
        };

        environment = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = "Environment variables to set for this container.";
          example = lib.literalExpression ''
            {
              DATABASE_HOST = "db.example.com";
              DATABASE_PORT = "3306";
            }
          '';
        };

        environmentFiles = lib.mkOption {
          type = lib.types.listOf lib.types.path;
          default = [ ];
          description = "Environment files for this container.";
          example = lib.literalExpression ''
            [
              /path/to/.env
              /path/to/.env.secret
            ]
          '';
        };

        log-driver = lib.mkOption {
          type = lib.types.str;
          default = "journald";
          description = ''
            Logging driver for the container.  The default of
            `"journald"` means that the container's logs will be
            handled as part of the systemd unit.

            For more details and a full list of logging drivers, refer to respective backends documentation.

            For Docker:
            [Docker engine documentation](https://docs.docker.com/engine/logging/configure/)

            For Podman:
            Refer to the {manpage}`docker-run(1)` man page.
          '';
        };

        ports = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Network ports to publish from the container to the outer host.

            Valid formats:
            - `<ip>:<hostPort>:<containerPort>`
            - `<ip>::<containerPort>`
            - `<hostPort>:<containerPort>`
            - `<containerPort>`

            Both `hostPort` and `containerPort` can be specified as a range of
            ports.  When specifying ranges for both, the number of container
            ports in the range must match the number of host ports in the
            range.  Example: `1234-1236:1234-1236/tcp`

            When specifying a range for `hostPort` only, the `containerPort`
            must *not* be a range.  In this case, the container port is published
            somewhere within the specified `hostPort` range.
            Example: `1234-1236:1234/tcp`

            Publishing a port bypasses the NixOS firewall. If the port is not
            supposed to be shared on the network, make sure to publish the
            port to localhost.
            Example: `127.0.0.1:1234:1234`

            Refer to the
            [Docker engine documentation](https://docs.docker.com/engine/network/#published-ports) for full details.
          '';
          example = [
            "127.0.0.1:8080:9000"
          ];
        };

        user = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            Override the username or UID (and optionally groupname or GID) used
            in the container.
          '';
          example = "nobody:nogroup";
        };

        workdir = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Override the default working directory for the container.";
          example = "/var/lib/hello_world";
        };

        dependsOn = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Define which other containers this one depends on. They will be added to both After and Requires for the unit.

            Use the same name as the attribute under `virtualisation.oci-containers.containers`.
          '';
          example = lib.literalExpression ''
            virtualisation.oci-containers.containers = {
              node1 = {};
              node2 = {
                dependsOn = [ "node1" ];
              }
            }
          '';
        };

        hostname = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "The hostname of the container.";
          example = "hello-world";
        };

        preRunExtraOptions = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Extra options for docker that go before the `run` argument.";
          example = [
            "--runtime"
            "runsc"
          ];
        };

        extraOptions = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Extra options for docker run`.";
          example = lib.literalExpression ''
            ["--network=host"]
          '';
        };

        autoStart = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            When enabled, the container is automatically started on boot.
            If this option is set to false, the container has to be started on-demand via its service.
          '';
        };

        pull = lib.mkOption {
          type = lib.types.enum [
            "always"
            "missing"
            "never"
            "newer"
          ];
          default = "missing";
          description = ''
            Image pull policy for the container. Must be one of: always, missing, never, newer
          '';
        };

        capabilities = lib.mkOption {
          type = lib.types.lazyAttrsOf (lib.types.nullOr lib.types.bool);
          default = { };
          description = ''
            Capabilities to configure for the container.
            When set to true, capability is added to the container.
            When set to false, capability is dropped from the container.
            When null, default runtime settings apply.
          '';
          example = lib.literalExpression ''
            {
              SYS_ADMIN = true;
              SYS_WRITE = false;
            {
          '';
        };

        devices = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            List of devices to attach to this container.
          '';
          example = lib.literalExpression ''
            [
              "/dev/dri:/dev/dri"
            ]
          '';
        };

        privileged = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Give extended privileges to the container
          '';
        };

        autoRemoveOnStop = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Automatically remove the container when it is stopped or killed
          '';
        };

        volumes = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            List of volumes to attach to this container.

            Note that this is a list of `"src:dst"` strings to
            allow for `src` to refer to `/nix/store` paths, which
            would be difficult with an attribute set.  There are
            also a variety of mount options available as a third
            field; please refer to the
            [docker engine documentation](https://docs.docker.com/engine/storage/volumes/) for details.
          '';
          example = lib.literalExpression ''
            [
              "volume_name:/path/inside/container"
              "/path/on/host:/path/inside/container"
            ]
          '';
        };

        networks = lib.mkOption {

          type = lib.types.attrsOf (
            lib.types.either lib.types.bool (lib.types.either lib.types.str (lib.types.attrsOf lib.types.str))
          );
          default = { };
          description = "Attached networks with their address";

          example = lib.literalExpression ''
            foo = true;                 # attach to network "foo", set ip automatically
            bar = "1.2.3.4";            # attach to network "foo", set ip manually
            lan = {
              ip = "10.10.0.100";       # attach to network "foo", with extra parameters
              ip6 = "fd00:0001::100";
            };
          '';
        };

        serviceOptions = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          description = "systemd service options that will be merged into systemd service definition for the container";
        };
      };
    };

  mkNetworkAttachmentArg =
    name: cfg:
    (
      if (cfg == true) then
        [ "--network=${lib.escapeShellArg name}" ]
      else if (builtins.isString cfg) then
        [ "--network=name=${lib.escapeShellArg name},ip=${lib.escapeShellArg cfg}" ]
      else
        [ "--network=${helpers.mkKvOpts ({ inherit name; } // cfg)}" ]
    );

  mkExtraOptions =
    name: cfg:
    (
      cfg.extraOptions
      ++ (lib.flatten (
        lib.mapAttrsToList (netName: netCfg: (mkNetworkAttachmentArg netName netCfg)) cfg.networks
      ))
    );

  mkOciContainer =
    name: cfg:
    (
      (lib.filterAttrs (n: v: builtins.elem n passThroughOptions) cfg)
      // {
        extraOptions = mkExtraOptions name cfg;
      }
    );

  networkServiceNames =
    networks:
    lib.mapAttrsToList (
      netName: netCfg: "${config.docker.networks.${netName}.serviceName}.service"
    ) networks;

  mkContainerService =
    name: cfg:
    lib.mkMerge [
      {
        after = networkServiceNames cfg.networks;
        requires = networkServiceNames cfg.networks;
      }
      cfg.serviceOptions
    ];

in

{
  options = {
    docker.containers = lib.mkOption {
      default = { };
      type = lib.types.attrsOf (lib.types.submodule containerOptions);
      description = "Docker container definitions";
    };
  };
  config = {
    virtualisation.oci-containers.containers = lib.mapAttrs' (
      n: v: lib.nameValuePair n (mkOciContainer n v)
    ) config.docker.containers;

    systemd.services = lib.mapAttrs' (
      n: v: lib.nameValuePair v.serviceName (mkContainerService n v)
    ) config.docker.containers;
  };
}

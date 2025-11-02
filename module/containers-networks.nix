{
  lib,
  helpers,
  config,
  ...
}:
let
  mkNetworkAttachmentArg =
    name: cfg:
    (
      if (cfg == true) then
        [ "--network=${lib.escapeShellArg name}" ]
      else if builtins.isString cfg then
        [ "--network=name=${lib.escapeShellArg name},ip=${lib.escapeShellArg cfg}" ]
      else
        [ "--network=${helpers.mkKvOpts ({ inherit name; } // cfg)}" ]
    );

  mkServiceName = netName: netCfg: "${config.docker.networks.${netName}.serviceName}.service";
in
{
  extraOptions = networks: lib.flatten (lib.mapAttrsToList mkNetworkAttachmentArg networks);
  serviceNames = networks: lib.mapAttrsToList mkServiceName networks;
}

{ lib }:
rec {
  mkDashDashOpts =
    attrs:
    lib.flatten (
      lib.mapAttrsToList (
        k: v:
        (
          if (builtins.isString v) then
            [ "--${k}=${lib.escapeShellArg v}" ]
          else if (builtins.isList v) then
            (builtins.map (item: "--${k}=${lib.escapeShellArg item}") v)
          else if v then
            [ "--${k}" ]
          else
            [ ]
        )
      ) attrs
    );

  mkKvOpts =
    attrs: lib.concatStringsSep "," (lib.mapAttrsToList (k: v: "${k}=${lib.escapeShellArg v}") attrs);
}

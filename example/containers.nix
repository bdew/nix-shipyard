{ pkgs, ... }:
{
  docker.containers = {
    foo =
      let
        testFile = pkgs.writeText "file.cfg" "This is a test";
      in
      {
        image = "foo/bar:latest";

        networks = {
          lan = true;
          front = {
            ip = "10.10.0.100";
            ip6 = "fd00:0001::100";
          };
        };

        serviceOptions = {
          after = [
            "docker-volume-bar.service"
          ];
          requires = [
            "docker-volume-bar.service"
          ];
        };

        volumes = {
          "/foo/bar" = {
            type = "volume";
            src = "othervol";
          };
          "/foo/config" = {
            type = "bind";
            src = testFile;
          };
          "/foo/fromfile" = {
            type = "bind";
            src = ./foo.txt;
          };
          "/baz" = "/test:ro:foo=bar";
          "/aaa" = "testvol:ro:foo=bar";
        };
      };
  };
}

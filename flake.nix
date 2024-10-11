{
  description = "An lsyncd container image created using Nix";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  };

  outputs = {self, ...} @ inputs:
    inputs.flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import inputs.nixpkgs {
        inherit system;
      };

      container_x86_64 = pkgs.dockerTools.buildLayeredImage {
        name = "lsyncd";
        tag = "latest-x86_64";
        config.Cmd = ["/bin/lsyncd"];
        contents = pkgs.buildEnv {
          name = "image-root";
          paths = with pkgs; [
            dockerTools.caCertificates
            lsyncd
            rsync
          ];
          pathsToLink = ["/bin" "/etc" "/var"];
        };
      };

      container_aarch64 = pkgs.pkgsCross.aarch64-multiplatform.dockerTools.buildLayeredImage {
        name = "lsyncd";
        tag = "latest-aarch64";
        config.Cmd = ["/bin/lsyncd"];
        contents = pkgs.pkgsCross.aarch64-multiplatform.buildEnv {
          name = "image-root";
          paths = with pkgs.pkgsCross.aarch64-multiplatform; [
            dockerTools.caCertificates
            lsyncd
            rsync
          ];
          pathsToLink = ["/bin" "/etc" "/var"];
        };
      };
    in {
      packages = {
        container_x86_64 = container_x86_64;
        container_aarch64 = container_aarch64;
      };

      devShells.default = pkgs.mkShell {
        packages = [
          pkgs.just
          pkgs.podman
        ];
      };
    });
}

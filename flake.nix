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

      pkgs_arm64 = import inputs.nixpkgs {
        system = "aarch64-linux";
      };

      lsync_world_script = {pkgs}:
        pkgs.writeShellScriptBin "lsync_world" ''
          function sigterm_handler() {
            while ${pkgs.procps}/bin/kill -0 $(${pkgs.coreutils}/bin/cat /tmp/minecraft.pid) &>/dev/null; do
              echo "Minecraft is still running, sleeping for 0.2s"
              ${pkgs.coreutils}/bin/sleep 0.2
            done

            echo "Syncing world to world state"
            ${pkgs.rsync}/bin/rsync /mnt/minecraft/world/ /mnt/state/world/
          }
          trap sigterm_handler SIGTERM

          ${pkgs.lsyncd}/bin/lsyncd -nodaemon -log all -rsync $1 $2
        '';

      container_x86_64 = pkgs.dockerTools.buildLayeredImage {
        name = "lsyncd";
        tag = "latest-x86_64";
        config.Cmd = ["/bin/lsyncd"];
        contents = pkgs.buildEnv {
          name = "image-root";
          paths = with pkgs; [
            dockerTools.caCertificates
            lsyncd
            (lsync_world_script {inherit pkgs;})
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
            (lsync_world_script {pkgs = pkgs_arm64;})
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

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
          LSYNCD_PIDFILE=/tmp/lsyncd.pid
          MINECRAFT_PIDFILE=/tmp/minecraft.pid

          function sigterm_handler() {
            echo "Received Sigterm, checking if Minecraft is still running..."
            while ${pkgs.procps}/bin/pkill -0 $MINECRAFT_PIDFILE &>/dev/null; do
              echo "Minecraft is still running, sleeping for 0.2s"
              ${pkgs.coreutils}/bin/sleep 0.2
            done
            echo "Minecraft now stopped..."

            echo "lsyncd pidfile..."
            if test -f $LSYNCD_PIDFILE; then
              echo -e "\tExists"
              echo "With content"
              ${pkgs.coreutils}/bin/cat $LSYNCD_PIDFILE
            else
              echo -e "\tDoes not exist"
            fi

            echo "Killing lsyncd"
            ${pkgs.procps}/bin/pkill -F $LSYNCD_PIDFILE

            echo "Syncing world: ( $1/ ) to world state: ( $2/ ) using rsync"
            ${pkgs.rsync}/bin/rsync $1/ $2/
          }
          trap "sigterm_handler $1 $2" SIGTERM

          ${pkgs.coreutils}/bin/ls -lad /tmp

          ${pkgs.lsyncd}/bin/lsyncd -log all -pidfile $LSYNCD_PIDFILE -rsync $1 $2 &

          while ${pkgs.procps}/bin/pkill -0 -F $LSYNCD_PIDFILE &>/dev/null; do
            ${pkgs.coreutils}/bin/sleep 5
          done
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
        fakeRootCommands = ''
          mkdir /tmp
          chmod 1777 /tmp
        '';
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
        fakeRootCommands = ''
          mkdir /tmp
          chmod 1777 /tmp
        '';
      };
    in {
      packages = {
        container_x86_64 = container_x86_64;
        container_aarch64 = container_aarch64;
      };

      devShells.default = pkgs.mkShell {
        packages = with pkgs; [
          just
          lsyncd
          podman
          procps
        ];
      };
    });
}

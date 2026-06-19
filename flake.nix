{
  description = "Mokuro Flake";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/25.11";

  outputs = {
    self,
    nixpkgs,
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
    };

    dependencies = with pkgs; [
      python310
      uv
      stdenv.cc.cc.lib
      zlib
      libxcb
      libGL
      glib
    ];

    libraryPaths = pkgs.lib.makeLibraryPath [
        pkgs.stdenv.cc.cc.lib
        pkgs.zlib
        pkgs.libxcb
        pkgs.libGL
        pkgs.glib
      ];
  in {
    devShells.${system}.default = pkgs.mkShell {
      nativeBuildInputs = dependencies ++ [self.packages.${system}.default];

      LD_LIBRARY_PATH = libraryPaths;

      shellHook = ''
      '';
    };

    packages.${system}.default = pkgs.writeShellApplication {
      name = "mokuro";
      runtimeInputs = dependencies;

      text = ''
        export LD_LIBRARY_PATH=${libraryPaths}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}

        # if [ ! -d ".venv" ]; then
        #   uv venv
        #   uv sync
        # fi

        uv run python -m mokuro "$@"
      '';
    };

    apps.${system}.default = {
      type = "app";
      program = "${self.packages.${system}.default}/bin/mokuro";
    };
  };
}

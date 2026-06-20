{
  description = "Mokuro Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/25.11";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-latest,
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
    };

    dependencies = with pkgs; [
      stdenv.cc.cc.lib
      zlib
      xorg.libxcb
      libGL
      glib
      python312
      uv
    ];

    libraryPackages = [
      pkgs.stdenv.cc.cc.lib
      pkgs.zlib
      pkgs.xorg.libxcb
      pkgs.libGL
      pkgs.glib
    ];
  in {
    devShells.${system} = {
      default = pkgs.mkShell {
        nativeBuildInputs = dependencies ++ [self.packages.${system}.default];

        LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath libraryPackages;

        shellHook = ''
        '';
      };
    };

    packages.${system} = {
      default = pkgs.writeShellApplication {
        name = "mokuro";
        runtimeInputs = dependencies;

        text = ''
          export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath libraryPackages}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}

          uv run python -m mokuro "$@"
        '';
      };
    };

    apps.${system} = {
      default = {
        type = "app";
        program = "${self.packages.${system}.default}/bin/mokuro";
      };
    };
  };
}

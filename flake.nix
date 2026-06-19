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

    pythonWithoutPackages = pkgs.python312;

    pythonWithPackages = pkgs.python312.withPackages (ps:
      with ps; [
        pytest
        fire #0.7.1
        loguru #0.7.3
        manga-ocr # 0.1.14
        natsort #8.4.0
        numpy #2.4.4
        opencv-python #4.13.0
        pillow #12.2.0
        pyclipper #1.4.0
        requests #2.33.1
        scipy #1.17.1
        setuptools #80.10.1
        shapely #2.1.2
        torch #2.12.0
        torchsummary #1.5.1
        torchvision #0.27.0
        transformers #5.5.4
        tqdm #4.41.0
        yattag #1.16.1
      ]);
  in {
    devShells.${system} = {
      default = pkgs.mkShell {
        nativeBuildInputs = [pythonWithoutPackages] ++ dependencies ++ [self.packages.${system}.default];

        LD_LIBRARY_PATH = libraryPaths;

        shellHook = ''
        '';
      };

      mokuro-nix = pkgs.mkShell {
        nativeBuildInputs = [pythonWithPackages] ++ dependencies ++ [self.packages.${system}.mokuro-nix];

        LD_LIBRARY_PATH = libraryPaths;

        shellHook = '''';
      };
    };

    packages.${system} = {
      default = pkgs.writeShellApplication {
        name = "mokuro";
        runtimeInputs = dependencies ++ [pythonWithoutPackages];

        text = ''
          export LD_LIBRARY_PATH=${libraryPaths}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}

          uv run python -m mokuro "$@"
        '';
      };

      mokuro-nix = pkgs.writeShellApplication {
        name = "mokuro";
        runtimeInputs =
          [pythonWithPackages] ++ dependencies;

        text = ''
          export LD_LIBRARY_PATH=${libraryPaths}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}

          python -m mokuro "$@"
        '';
      };
    };

    apps.${system}.default = {
      type = "app";
      program = "${self.packages.${system}.default}/bin/mokuro";
    };
  };
}

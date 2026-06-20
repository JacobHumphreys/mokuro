{
  description = "Mokuro Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/25.11";
    self.submodules = true;
    comic-text-detector = {
      url = "path:./comic_text_detector";
      flake = false;                 # Set to false if not a flake
    };
  };

  outputs = {
    self,
    nixpkgs,
    comic-text-detector,
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
    };

    libraryPackages = with pkgs; [
      stdenv.cc.cc.lib
      zlib
      xorg.libxcb
      libGL
      glib
    ];

    pythonWithoutPackages = with pkgs; [python312 uv];

    pythonWithPackages = pkgs.python312.withPackages (ps:
      with ps; [
        pytest
        ruff

        fire
        loguru
        manga-ocr
        natsort
        numpy
        opencv-python
        pillow
        pyclipper
        requests
        scipy
        setuptools
        shapely
        torch
        torchsummary
        torchvision
        transformers
        tqdm
        yattag
      ]);

    torchLib = "${pythonWithPackages}/lib/${pkgs.python312.libPrefix}/site-packages/torch/lib";

    src = pkgs.fetchgit {
      url = "file://${./.}";
      submodules = true;
    };

    comic-text-detector-src = pkgs.fetchFromGitHub {
      owner = "kha-white";
      repo = "comic-text-detector";
      rev = "master";
      sha256 = "lxmcDuPRlRABkXJP2oNvjRLxRJpqK6mn+F4kaGvnz/k="; # nix build will tell you the real hash, then paste it in
    };

    combined_src = pkgs.runCommand "mokuro-combined-src" {} ''
      mkdir -p $out
      cp -r ${src}/. $out/
      cp -r ${comic-text-detector-src}/* $out/comic_text_detector/
      chmod -R u+w $out
    '';
  in {
    devShells.${system} = {
      default = pkgs.mkShell {
        nativeBuildInputs =
          [pythonWithPackages]
          ++ libraryPackages
          ++ [self.packages.${system}.development];

        LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath (libraryPackages ++ [pythonWithPackages]);

        shellHook = '''';
      };

      devUv = pkgs.mkShell {
        nativeBuildInputs =
          pythonWithoutPackages
          ++ libraryPackages
          ++ [self.packages.${system}.uv-local];

        LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath libraryPackages;

        shellHook = '''';
      };
    };

    packages.${system} = {
      # Runs off of nix store copy
      default = pkgs.writeShellApplication {
        name = "mokuro";
        runtimeInputs =
          [pythonWithPackages] ++ libraryPackages;

        text = ''
          # Script called when command mokuro is used

          export CUDA_VISIBLE_DEVICES=""
          export LD_LIBRARY_PATH=${torchLib}:${pkgs.lib.makeLibraryPath ([pythonWithPackages]
              ++ libraryPackages)}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}

          # This is used to avoid an issue with deadlocking.
          # Does not seem to greatly hinder performance.
          export OMP_NUM_THREADS=1
          export MKL_NUM_THREADS=1
          export OPENBLAS_NUM_THREADS=1
          export CV2_NUM_THREADS=1

          #Goto nix store copy of repo
          cd ${src}
          ls comic_text_detector

          #convert paths to absolute. Mokuro will run in the store not from cwd.
          args=()
          for path in "$@"; do
            args+=("$(realpath "$OLDPWD/$path")")
          done

          python -m mokuro "''${args[@]}"
        '';
      };

      #runs mokuro locally using nixpkgs
      development = pkgs.writeShellApplication {
        name = "mokuro";
        runtimeInputs =
          [pythonWithPackages] ++ libraryPackages;

        text = ''
          # Warning this is using nixpkgs to provide python depenedencies

          export CUDA_VISIBLE_DEVICES=""
          export LD_LIBRARY_PATH=${torchLib}:${pkgs.lib.makeLibraryPath ([pythonWithPackages]
              ++ libraryPackages)}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}

          # This is used to avoid an issue with deadlocking.
          # Does not seem to greatly hinder performance.
          export OMP_NUM_THREADS=1
          export MKL_NUM_THREADS=1
          export OPENBLAS_NUM_THREADS=1
          export CV2_NUM_THREADS=1

          echo "Warning: Development Build Running Locally"
          python -m mokuro "$@"
        '';
      };

      # Runs mokuro through python via uv/pip and venv.
      uv-local = pkgs.writeShellApplication {
        name = "mokuro";
        runtimeInputs = libraryPackages ++ pythonWithoutPackages;

        text = ''
          export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath libraryPackages}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}

          echo "Waring: This version of Mokuro only works from within its repository due to the immutable nix store. This is intended to be used for development only. If you are trying to use mokuro as a package, please use the default package"
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

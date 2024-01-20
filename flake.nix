{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;
      imports = [];
      perSystem = { config, self', pkgs, lib, system, ... }:
        let
          gitDeps = {
            angle2 = builtins.fetchGit {
              url = "https://chromium.googlesource.com/angle/angle.git";
              rev = "40b6739712d38a6950ddba1871a0fae10a974224";
              submodules = false;
            };
            dng_sdk = builtins.fetchGit {
              url = "https://android.googlesource.com/platform/external/dng_sdk.git";
              ref = "refs/heads/android14-security-release";
              rev = "4689f810a78c351d4ae1bbd7aa3323bbc684c2dc";
            };
            piex = builtins.fetchGit {
              #url = "https://android.googlesource.com/platform/external/piex.git";
              #url = "https://github.com/google/piex";
              #ref = "refs/tags/v0.27";
              # fixed a build error
              url = "https://github.com/warrenfalk/piex";
              ref = "refs/heads/master";
              rev = "851c5e10d01d988aceffeefd3892dbf6d1d3ab67";
            };
            sfntly = builtins.fetchGit {
              # also consider https://github.com/rillig/sfntly which contains newer features
              url = "https://github.com/googlefonts/sfntly.git";
              rev = "a56f5782f209771aa226063757d57e6b5c948478";
            };
            wuffs = builtins.fetchGit {
              url = "https://github.com/google/wuffs.git";
              ref = "refs/tags/v0.3.3";
              rev = "d910658bcea64720c8a133e816c81d77293d9cde";
            };
          };
          deps = with pkgs; [
            python3
            gn
            ninja
            
            fontconfig
            expat
            icu
            libglvnd
            libjpeg
            libpng
            libwebp
            xorg.libX11
            zlib
            mesa
            harfbuzzFull            
          ];
        in
        {
          # build artifact
          packages.default = pkgs.stdenv.mkDerivation {
            name = "skia";
            src = ./.;
            buildInputs = [];
            nativeBuildInputs = deps;
            CLANGCC = "${pkgs.clang}/bin/clang";
            CLANGCXX = "${pkgs.clang}/bin/clang++";
            SKIA_NINJA_COMMAND = "${pkgs.ninja}/bin/ninja";
            SKIA_GN_COMMAND = "${pkgs.gn}/bin/gn";
            LIBCLANG_PATH = "${pkgs.libclang.lib}/lib";

            preConfigure = with gitDeps; ''
              mkdir -p third_party/externals
              ln -s ${angle2} third_party/externals/angle2
              ln -s ${dng_sdk} third_party/externals/dng_sdk
              ln -s ${piex} third_party/externals/piex
              ln -s ${sfntly} third_party/externals/sfntly
              ln -s ${wuffs} third_party/externals/wuffs
            '';            

            configurePhase = ''
              runHook preConfigure
              gn gen out/Release --args="is_debug=false is_official_build=true extra_cflags=[\"-I${pkgs.harfbuzzFull.dev}/include/harfbuzz\"]"
              runHook postConfigure
            '';

            buildPhase = ''
              runHook preBuild
              ninja -C out/Release skia modules
              runHook postBuild
            '';

            installPhase = ''
              mkdir -p $out
              # Glob will match all subdirs.
              shopt -s globstar

              # dump out the defines lines of the ninja files as some consumers may need to know the defines
              find out/Release/obj -name '*.ninja' -exec grep -H 'defines = ' {} \; >> $out/defines.txt

              cp -r --parents -t $out/ \
                include/* \
                out/Release/*.a \
                src/gpu/**/*.h \
                src/core/*.h \
                src/base/*.h \
                modules/skshaper/include/*.h \
                modules/skcms/**/*.h \
                third_party/externals/angle2/include
            '';
          };


          # dev environment
          devShells.default = pkgs.mkShell {
            inputsFrom = [];
            shellHook = ''
            '';
            buildInputs = deps;
            nativeBuildInputs = with pkgs; [
            ];
          };
        };
    };
}



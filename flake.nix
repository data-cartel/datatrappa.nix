{
  inputs = {
    # Nix
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    systems.url = "github:nix-systems/default";
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pre-commit-hooks.follows = "pre-commit-hooks";
    };
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Scala
    typelevel = {
      url = "github:typelevel/typelevel-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sbt = {
      url = "github:zaninime/sbt-derivation";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, systems, flake-utils, pre-commit-hooks, devenv
    , deploy-rs, typelevel, sbt, }@inputs:
    {
      deploy.nodes.example = {
        hostname = "placeholder";
        sshOpts = [ "-p" "666420" ];
        profiles.akash = {
          user = "root";
          path = deploy-rs.lib.x86_64-linux.activate.custom
            self.packages.x86_64-linux.default "bin/sparcala";
        };
      };

      checks = builtins.mapAttrs
        (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
    } // flake-utils.lib.eachDefaultSystem (system:
      let
        version = "0.1.0";
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ typelevel.overlays.default ];
        };

        kafka = import ./kafka.nix { inherit pkgs; };
        spark = import ./spark.nix { inherit pkgs; };

        sparcala = {
          name = "sparcala";
          jar = sbt.mkSbtDerivation.${system} {
            pname = sparcala.name;
            version = version;
            src = ./.;

            # Note: if you update nixpkgs, sbt-derivation or the dependencies in your project, the hash will change!
            depsSha256 = "sha256-v50Nq5CFQrJTg7HbGWwtAdeqnshqj3cQtasYo/Rkzho=";
            buildPhase = "sbt assembly";
            installPhase = ''
              mkdir -p $out/
              cp sparcala/target/scala-2.13/sparcala.jar $out/
            '';
          };

          package = pkgs.writeShellApplication {
            name = sparcala.name;
            runtimeInputs = [ pkgs.jdk11 sparcala.jar ];
            text = "${pkgs.jdk11}/bin/java -jar ${sparcala.jar}/sparcala.jar";
          };

          bin = "${sparcala.package}/bin/${sparcala.name}";
          app = {
            type = "app";
            program = sparcala.bin;
          };

          docker = pkgs.dockerTools.buildImage {
            name = sparcala.name;
            tag = version;
            copyToRoot = pkgs.buildEnv {
              name = sparcala.name;
              paths = [ sparcala.package sparcala.jar ];
              pathsToLink = [ "/bin" ];
            };
            config.Cmd = [ sparcala.bin ];
          };
        };

        envvars = spark.env // rec {
          OTEL_COLLECTOR_ENDPOINT = "http://localhost:4317";
          DATA_DIR = "./data";
        };

        hooks = {
          nil.enable = true;
          nixfmt = {
            enable = true;
            package = pkgs.nixfmt-classic;
          };

          scalafmt = {
            enable = true;
            name = "scalafmt";
            files = ".*\\.scala$";
            entry = "${pkgs.scalafmt}/bin/scalafmt";
            pass_filenames = false;
          };
          scalafix = {
            enable = true;
            name = "scalafix";
            files = ".*\\.scala$";
            entry = "${pkgs.sbt}/bin/sbt scalafix";
            pass_filenames = false;
            raw.verbose = true;
          };
        };

      in rec {
        packages = kafka.packages // spark.packages // rec {
          scalapuff = sparcala.package;
          devenv-up = self.devShells.${system}.default.config.procfileScript;
          default = devenv-up;
        };

        apps = kafka.apps // { scalapuff = sparcala.app; };

        devShells.default = devenv.lib.mkShell {
          inherit inputs pkgs;
          modules = let cmd = kafka.cmd // spark.cmd;
          in [{
            # https://devenv.sh/reference/options/
            packages = with pkgs;
              [
                nil
                nixfmt-classic
                dhall
                pqrs
                parquet-tools
                metals
                pyright
                black
                plumber
                # grafana
                # prometheus
              ] ++ kafka.shellDeps ++ spark.shellDeps;

            languages = {
              nix.enable = true;
              scala.enable = true;
              python = {
                enable = true;
                venv = {
                  enable = true;
                  quiet = true;
                  requirements = builtins.readFile ./requirements.txt;
                };
              };
            };

            process = let join = pkgs.lib.concatStringsSep "\n";
            in with cmd; {
              before = join [ kafkup sparkup ];
              after = join [ kafkout sparkout ];
            };
            processes = with cmd; { scalapuff.exec = scalapuff; };
            scripts = pkgs.lib.mapAttrs (cmd: exec: { inherit exec; }) cmd;

            env = envvars;
            pre-commit = { inherit hooks; };
            difftastic.enable = true;
            cachix.enable = true;
          }];
        };

        checks = {
          pre-commit = pre-commit-hooks.lib.${system}.run {
            src = ./.;
            inherit hooks;
          };
        };
      });

  nixConfig = {
    extra-substituters = "https://devenv.cachix.org";
    extra-trusted-public-keys =
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
  };
}

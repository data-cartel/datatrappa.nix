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
    , typelevel, sbt, }@inputs:
    flake-utils.lib.eachDefaultSystem (system:
      let
        version = "0.1.0";
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ typelevel.overlays.default ];
          # openssl = nixpkgs.openssl_3;
        };

        kafka = import ./kafka.nix { inherit pkgs; };
        spark = {
          pkg = pkgs.spark.overrideAttrs (super: rec {
            pname = "spark";
            version = "3.5.1";
            untarDir = "${pname}-${version}";
            hadoopSupport = false;
            src = pkgs.fetchzip {
              url =
                "mirror://apache/spark/${pname}-${version}/${pname}-${version}-bin-hadoop3-scala2.13.tgz";
              sha256 = "sha256-2SigM9iAsbXiw6znSlqT2xoaHbU5HXm4bUnyXmpMueM";
            };
          });

          home = "${spark.pkg}";
          env = {
            SPARK_HOME = "${spark.home}";
            SPARK_CONF_DIR =
              "~/code/0xgleb/data-cartel/datatrappa.nix/sparkonf";
            SPARK_LOG_DIR = "/var/log/spark";
            SPARK_WORKER_DIR = "/var/lib/spark";
            SPARK_LOCAL_IP = "127.0.0.1";
            SPARK_MASTER = "";
            SPARK_MASTER_HOST = "127.0.0.1";
            SPARK_MASTER_PORT = "7077";
            SPARK_WORKER_CORES = "8";
            SPARK_WORKER_MEMORY = "8g";
          };
        };

        scala = {
          mkJar = scalaVersion: project:
            pkgs.stdenv.mkDerivation {
              name = "${project}-jar-${version}";
              src = ./.;
              buildInputs = [ pkgs.jdk11 pkgs.sbt ];
              # export SBT_DEPS=$(mktemp -d)
              # export SBT_OPTS="-Dsbt.global.base=$SBT_DEPS/project/.sbtboot -Dsbt.boot.directory=$SBT_DEPS/project/.boot -Dsbt.ivy.home=$SBT_DEPS/project/.ivy $SBT_OPTS"
              # export COURSIER_CACHE=$SBT_DEPS/project/.coursier
              # mkdir -p $SBT_DEPS/project/{.sbtboot,.boot,.ivy,.coursier}
              buildPhase = ''
                ${pkgs.sbt}/bin/sbt ${project}/assembly
              '';
              installPhase = ''
                mkdir -p $out/bin
                cp ${project}/target/scala-${scalaVersion}/${project}.jar $out/bin/${project}.jar
              '';
            };

          deps = [ pkgs.scalafmt spark.pkg ];
        };

        sparcala = {
          name = "sparcala";
          jar = sbt.mkSbtDerivation.${system} {
            pname = sparcala.name;
            version = version;
            src = ./.;

            # Note: if you update nixpkgs, sbt-derivation or the dependencies in your project, the hash will change!
            depsSha256 = "sha256-Nn6C7GOHnqCqSG01WiGrbU49M4899NWpIdpXWhI4kzU=";
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
        packages = kafka.packages // {
          spark = spark.pkg;
          sparcala = sparcala.package;
          devenv-up = self.devShells.${system}.default.config.procfileScript;
        };

        apps = kafka.apps // { sparcala = sparcala.app; };

        devShells.default = devenv.lib.mkShell {
          inherit inputs pkgs;
          modules = [{
            # https://devenv.sh/reference/options/
            packages = with pkgs;
              [
                nil
                nixfmt-classic
                dhall
                pqrs
                parquet-tools
                jdk11
                metals
                grafana
                prometheus
              ] ++ kafka.shellDeps ++ scala.deps;

            env = envvars;
            pre-commit = { inherit hooks; };
            difftastic.enable = true;
            cachix.enable = true;

            languages = {
              nix.enable = true;
              scala.enable = true;
            };

            scripts = kafka.scripts // {
              sparkup.exec = ''
                ${spark.pkg}/bin/start-master.sh \
                  && ${spark.pkg}/bin/start-worker.sh spark://127.0.0.1:7077
              '';

              sparkout.exec = ''
                ${spark.pkg}/bin/stop-worker.sh \
                  && ${spark.pkg}/bin/stop-master.sh
              '';

              scalapuff.exec = ''
                ${pkgs.sbt}/bin/sbt assembly \
                  && ${spark.pkg}/bin/spark-submit \
                      --class data.cartel.sparcala.Sparcala \
                      --master spark://${spark.env.SPARK_MASTER_HOST}:${spark.env.SPARK_MASTER_PORT} \
                      sparcala/target/scala-2.13/sparcala.jar
              '';
            };
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

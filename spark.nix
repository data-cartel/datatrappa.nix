{ pkgs }: rec {
  apacheSpark = pkgs.spark.overrideAttrs (super: rec {
    pname = "apache-spark";
    version = "3.5.1";
    untarDir = "${pname}-${version}";
    hadoopSupport = false;

    src = let
      baseUrl = "https://downloads.apache.org/spark";
      archive = "spark-${version}-bin-hadoop3-scala2.13.tgz";
    in pkgs.fetchurl {
      url = "${baseUrl}/spark-${version}/${archive}";
      sha256 = "sha256-3e+9/sFKYYefoJQzwh+ZzgkNi4WLF7SsGH6TRBsad5c=";
    };
  });

  home = "${apacheSpark}";
  env = {
    SPARK_HOME = "${home}";
    SPARK_CONF_DIR = ./sparkonf;
    SPARK_LOG_DIR = "/var/log/spark";
    SPARK_WORKER_DIR = "/var/lib/spark";
    SPARK_LOCAL_IP = "127.0.0.1";
    SPARK_MASTER = "";
    SPARK_MASTER_HOST = "127.0.0.1";
    SPARK_MASTER_PORT = "7077";
    SPARK_WORKER_CORES = "8";
    SPARK_WORKER_MEMORY = "8g";
  };

  packages = rec {
    spark = apacheSpark;
    serverProperties = pkgs.stdenv.mkDerivation {
      name = "server.properties";
      src = ./config;
      buildInputs = [ pkgs.dhall ];
      buildPhase = ''
        ${pkgs.dhall}/bin/dhall text --file kraft.dhall > server.properties
      '';
      installPhase = ''
        cp -v server.properties $out
      '';
    };
  };

  shellDeps = with pkgs; [ jdk11 scalafmt apacheSpark ];
  pkg = apacheSpark;

  cmd = {
    sparkup = ''
      ${pkg}/bin/start-master.sh \
        && ${pkg}/bin/start-worker.sh spark://127.0.0.1:7077
    '';

    sparkout = ''
      ${pkg}/bin/stop-worker.sh \
        && ${pkg}/bin/stop-master.sh
    '';

    scalapuff = ''
      ${pkgs.sbt}/bin/sbt assembly \
        && ${pkg}/bin/spark-submit \
            --class data.cartel.sparcala.Sparcala \
            --master spark://${env.SPARK_MASTER_HOST}:${env.SPARK_MASTER_PORT} \
            sparcala/target/scala-2.13/sparcala.jar
    '';
  };
}

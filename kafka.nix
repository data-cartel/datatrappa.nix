{ pkgs }: rec {
  apacheKafka = pkgs.apacheKafka.overrideAttrs (super: rec {
    kafkaVersion = "3.7.1";
    scalaVersion = "2.13";

    pname = "apache-kafka";
    version = "${scalaVersion}-${kafkaVersion}";
    src = pkgs.fetchurl {
      url = let
        baseUrl = "https://downloads.apache.org/kafka";
        archive = "kafka_${scalaVersion}-${kafkaVersion}.tgz";
      in "${baseUrl}/${kafkaVersion}/${archive}";
      sha256 = "sha256-YqyuShQ92YPcfrSATVdEugxQsZm1CPWZ7wAQIOJVj8k=";
    };
  });

  packages = rec {
    kafka = apacheKafka;
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

  shellDeps = with pkgs; [ apacheKafka kafkactl zulu ];

  scripts = with packages; {
    kafkup.exec = let
      storage = "${apacheKafka}/bin/kafka-storage.sh";
      start = "${apacheKafka}/bin/kafka-server-start.sh";
    in ''
      export KAFKA_DEBUG=true

      if [ -z "$KAFKA_CLUSTER_ID" ]; then
        export KAFKA_CLUSTER_ID=$(${storage} random-uuid)
      fi

      ${storage} format -g -t "$KAFKA_CLUSTER_ID" -c ${serverProperties}
      ${start} -daemon ${serverProperties}
    '';

    kafkout.exec = ''
      ${apacheKafka}/bin/kafka-server-stop.sh
    '';
  };
}

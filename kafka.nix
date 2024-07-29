{ pkgs }: rec {
  apacheKafka = pkgs.apacheKafka.overrideAttrs (super: rec {
    pname = "apache-kafka";
    version = "2.13-3.7.0";
    src = pkgs.fetchurl {
      url =
        "https://downloads.apache.org/kafka/${version}/kafka_${version}.tgz";
      sha256 = "sha256-ZfJuWTe7t23+eN+0FnMN+n4zeLJ+E/0eIE8aEJm/r5w=";
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

  cmd = with packages; {
    kafkup = let
      storage = "${apacheKafka}/bin/kafka-storage.sh";
      start = "${apacheKafka}/bin/kafka-server-start.sh";
    in ''
      if [ -z "$KAFKA_CLUSTER_ID" ]; then
        export KAFKA_CLUSTER_ID=$(${storage} random-uuid)
        rm -rfv /tmp/kraft-combined-logs
      fi

      ${storage} format -g -t "$KAFKA_CLUSTER_ID" -c ${serverProperties}
      ${start} -daemon ${serverProperties}
    '';

    kafkout = ''
      ${apacheKafka}/bin/kafka-server-stop.sh
    '';
  };
}

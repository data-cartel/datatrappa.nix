let KafkaBroker = ./schema/broker.dhall

let broker
    : KafkaBroker
    = { security_protocol = "PLAINTEXT"
      , bootstrap_servers = "localhost:9092"
      , credentials_required = False
      }

in  broker

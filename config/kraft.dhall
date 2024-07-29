let cluster =
      let security_protocol = "PLAINTEXT"

      in  { broker =
            { name = security_protocol
            , security_protocol
            , port = "9092"
            , host = "localhost"
            , credentials =
                None
                  { sasl_mechanism : Text
                  , kafka_api_key : Text
                  , kafka_api_secret : Text
                  }
            }
          }

let
    -- The role of this server. Setting this puts us in KRaft mode
    process =
      { roles = "broker,controller" }

let
    -- The node id associated with this instance's roles
    node =
      { id = "1" }

let
    -- The connect string for the controller quorum
    controller =
      { quorum.voters = "1@localhost:9093"
      ,   -- A comma-separated list of the names of the listeners used by the controller.
          -- If no explicit mapping set in `listener_security.protocol_map`, default will be using PLAINTEXT protocol
          -- This is required if running in KRaft mode.
          listener
        . names
        = "CONTROLLER"
      }

let listeners =
      "${cluster.broker.name}://:${cluster.broker.port},CONTROLLER://:9093"

let
    -- Listener name, hostname and port the broker will advertise to clients.
    -- If not set, it uses the value for "listeners".
    advertised_listeners =
      "${cluster.broker.name}://${cluster.broker.host}:${cluster.broker.port}"

let
    -- Maps listener names to security protocols, the default is for them to be the same. See the config documentation for more details
    listener_security_protocol_map =
      "CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,SSL:SSL,SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_SSL:SASL_SSL"

let num =
      {   -- The number of threads that the server uses for receiving requests from the network and sending responses to the network
          network
        . threads
        = "8"
      ,   -- The number of threads that the server uses for processing requests, which may include disk I/O
          io
        . threads
        = "8"
      , -- The default number of log partitions per topic. More partitions allow greater
        -- parallelism for consumption, but this will also result in more files across
        -- the brokers.
        partitions = "3"
      ,   -- The number of threads per data directory to be used for log recovery at startup and flushing at shutdown.
          -- This value is recommended to be increased for installations with data dirs located in RAID array.
          recovery
        . threadsPerDataDir
        = "4"
      }

let socket =
      {   -- The send buffer (SO_SNDBUF) used by the socket server
          send
        . buffer
        . bytes
        = "102400"
      ,   -- The receive buffer (SO.RCVBUF) used by the socket server
          receive
        . buffer
        . bytes
        = "102400"
      ,   -- The maximum size of a request that the socket server will accept (protection against OOM)
          request
        . max
        . bytes
        = "104857600"
      }

let log =
      { retention = { hours = "4", check.interval.ms = "300000" }
      , segment.bytes = "1073741824"
      , dirs = "/tmp/kraft-combined-logs"
      , flush.interval.messages = "100"
      , flush.interval.ms = "1000"
      }

let offsets = { topic.replication.factor = "3" }

let autoCreateTopicsEnable = "true"

let transaction = { state.log = { replication.factor = "1", min.isr = "1" } }

in  ''
    auto.create.topics.enable=${autoCreateTopicsEnable}
    process.roles=${process.roles}
    node.id=${node.id}
    controller.quorum.voters=${controller.quorum.voters}
    listeners=${listeners}
    inter.broker.listener.name=${cluster.broker.name}
    advertised.listeners=${advertised_listeners}
    controller.listener.names=${controller.listener.names}
    listener.security.protocol.map=${listener_security_protocol_map}
    num.network.threads=${num.network.threads}
    num.io.threads=${num.io.threads}
    socket.send.buffer.bytes=${socket.send.buffer.bytes}
    socket.receive.buffer.bytes=${socket.receive.buffer.bytes}
    socket.request.max.bytes=${socket.request.max.bytes}
    log.retention.hours=${log.retention.hours}
    log.segment.bytes=${log.segment.bytes}
    log.retention.check.interval.ms=${log.retention.check.interval.ms}
    log.dirs=${log.dirs}
    num.partitions=${num.partitions}
    num.recovery.threads.per.data.dir=${num.recovery.threadsPerDataDir}
    offsets.topic.replication.factor=${offsets.topic.replication.factor}
    transaction.state.log.replication.factor=${transaction.state.log.replication.factor}
    transaction.state.log.min.isr=${transaction.state.log.min.isr}
    ''

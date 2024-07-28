let rust_type = env:rust_type ? (\(T : Type) -> \(T : Type) -> T)

in  rust_type
      < KafkaBroker >
      { bootstrap_servers : Text
      , security_protocol : Text
      , credentials_required : Bool
      }

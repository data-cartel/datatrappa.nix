from kafka import KafkaProducer

producer = KafkaProducer(bootstrap_servers="localhost:9092")
topic = "foobar"

for i in range(100):
    print(f"Sending message {i}")
    producer.send(topic, b"some_message_bytes")

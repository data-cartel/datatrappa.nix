# join a consumer group for dynamic partition assignment and offset commits
from kafka import KafkaConsumer

consumer = KafkaConsumer("foobar", bootstrap_servers="localhost:9092")
# or as a static member with a fixed group member name
# consumer = KafkaConsumer('my_favorite_topic', group_id='my_favorite_group',
#                          group_instance_id='consumer-1', leave_group_on_close=False)
for msg in consumer:
    print(msg)

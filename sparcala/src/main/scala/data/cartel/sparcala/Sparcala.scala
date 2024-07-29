package data.cartel.sparcala

import scala.jdk.CollectionConverters._

import org.apache.spark.SparkConf
import org.apache.spark.sql.SparkSession

object Sparcala {
  def main(args: Array[String]): Unit = {
    val masterHost = sys.env.get("SPARK_MASTER_HOST").get
    val masterPort = sys.env.get("SPARK_MASTER_PORT").get

    val conf =
      new SparkConf()
        .set("spark.sql.adaptive.enabled", "false")
        .setMaster(s"spark://$masterHost:$masterPort")
        .setAppName("Sparcala")

    val spark =
      SparkSession
        .builder()
        .config(conf)
        .appName("SPARCALA")
        .config("spark.jars.packages", "org.apache.spark:spark-sql-kafka-0-10_2.13")
        .getOrCreate()

    spark.sparkContext.setLogLevel("DEBUG")

    val producerParams = scala.collection.mutable
      .Map[String, Object](
        "bootstrap.servers" -> "localhost:9092",
        // "key.deserializer" -> classOf[StringDeserializer],
        // "value.deserializer" -> classOf[StringDeserializer],
        // "key.serializer" -> classOf[StringSerializer],
        // "value.serializer" -> classOf[StringSerializer],
        // "group.id" -> "smoketest",
        "auto.offset.reset" -> "latest",
        "enable.auto.commit" -> (false: java.lang.Boolean)
      )
      .asJava

    val topic = "smoketest"
    // val admin = AdminClient.create(kafkaParams)
    // val newTopic = new NewTopic(topic, 1, 1.toShort)
    // admin.createTopics(Seq(newTopic).asJava)

    val df = spark.read.text("README.md")

    df.show()
    df.write
      .format("kafka")
      .option("kafka.bootstrap.servers", "localhost:9092")
      .option("topic", topic)
      .save()

    val stream = spark.readStream
      .format("kafka")
      .option("kafka.bootstrap.servers", "localhost:9092")
      .option("subscribe", topic)
      .load()

    stream.writeStream
      .format("console")
      .start()
      .awaitTermination()

    spark.stop()
  }
}

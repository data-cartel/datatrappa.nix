package data.cartel.sparcala

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

    spark.sparkContext.setLogLevel("INFO")

    val topic = "foobar"
    val stream = spark.readStream
      .format("kafka")
      .option("kafka.bootstrap.servers", "localhost:9092")
      .option("subscribe", topic)
      .load()

    stream.writeStream
      .format("parquet")
      .option("path", "data")
      .option("checkpointLocation", "/tmp/checkpoint")
      .start()
      .awaitTermination()

    spark.stop()
  }
}

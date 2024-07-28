package data.cartel.sparcala

import org.apache.spark.SparkConf
import org.apache.spark.sql.{SaveMode, SparkSession}
import org.apache.spark.sql.functions._
import org.apache.spark.sql.streaming.Trigger

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
      SparkSession.builder().config(conf).appName("SPARCALA").getOrCreate()
    spark.sparkContext.setLogLevel("WARN")

    val df = spark.read.text("README.md")

    df.show()

    import spark.implicits._
    val ds = df
      .selectExpr("CAST(value AS STRING)")
      .writeStream
      .format("kafka")
      .option("kafka.bootstrap.servers", "localhost:9092")
      .option("topic", "smoketest")
      .start()

    spark.stop()
  }

  // def stream(spark: SparkSession, dataDir: String) = {
  //   import spark.implicits._

  //   val blocks = spark.readStream.schema(Shape.block).json(s"$dataDir/blocks")

  //   val addresses =
  //     blocks
  //       .select($"chain", explode(col("transactions")).as("tx"))
  //       .select($"chain", array(col("tx.to")).as("addresses"))
  //       .select($"chain", explode(col("addresses")).as("address"))
  //       .where("address is not null")

  //   addresses.writeStream
  //     .option("checkpointLocation", s"$dataDir/getcode/.checkpoint")
  //     .foreachBatch {
  //       (batchDf: org.apache.spark.sql.DataFrame, batchId: Long) =>
  //         println(s"batchId = $batchId, batchDf.count() = ${batchDf.count()}")
  //         val distinctDf = batchDf.distinct()
  //         println(
  //           s"batchId = $batchId, distinctDf.count() = ${distinctDf.count()}"
  //         )

  //         distinctDf.write
  //           .mode(SaveMode.Append)
  //           .json(s"$dataDir/getcode")
  //     }
  //     .trigger(Trigger.ProcessingTime("1 minute"))
  //     .start()
  //     .awaitTermination()
  // }
}

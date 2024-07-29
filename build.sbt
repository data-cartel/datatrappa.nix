ThisBuild / organization := "data.cartel"
ThisBuild / version := "0.1.0"
ThisBuild / resolvers ++= Seq(
  "s01-oss-sonatype".at("https://s01.oss.sonatype.org/content/repositories/snapshots"),
  Resolver.url(
    "typesafe",
    url("https://repo.typesafe.com/typesafe/ivy-releases/")
  )(
    Resolver.ivyStylePatterns
  )
)

Global / onChangedBuildSource := ReloadOnSourceChanges
ThisBuild / scalafixDependencies += "org.typelevel" %% "typelevel-scalafix" % "0.3.1"
ThisBuild / testFrameworks += new TestFramework("munit.Framework")
Test / testOptions += Tests.Argument(
  TestFrameworks.MUnit
    // "-F",
    // "munit.MinimizedConsoleReporter"
)

lazy val munit =
  libraryDependencies ++= Seq(
    "org.scalameta" %% "munit" % "0.7.29" % Test,
    "org.typelevel" %% "munit-cats-effect" % "2.0.0-M3" % Test
  )

val Scala2 = "2.13.14"
lazy val scala2Settings = Seq(
  scalaVersion := Scala2,
  semanticdbEnabled := true,
  semanticdbVersion := scalafixSemanticdb.revision,
  scalacOptions ++= Seq(
    "-Ytasty-reader",
    "-Wunused:imports",
    "-Yrangepos",
    "-feature"
  )
)

lazy val root = (project in file("."))
  .aggregate(sparcala)
  .settings(
    name := "datatrappa"
    // scalafixOnCompile := true
  )

val SparkVersion = "3.5.1"
val KafkaVersion = "3.7.0"

lazy val sparcala = (project in file("sparcala"))
  .settings(scala2Settings)
  .settings(name := "sparcala")
  .settings(
    libraryDependencies ++= Seq(
      "org.apache.spark" %% "spark-core" % SparkVersion % Provided,
      "org.apache.spark" %% "spark-sql" % SparkVersion % Provided,
      "org.apache.spark" %% "spark-sql-kafka-0-10" % SparkVersion,
      "org.apache.spark" %% "spark-streaming" % SparkVersion,
      "org.apache.spark" %% "spark-streaming-kafka-0-10" % SparkVersion
      // "org.apache.kafka" % "kafka-streams" % KafkaVersion
    ),
    assembly / mainClass := Some("data.cartel.sparcala.Sparcala"),
    assembly / assemblyJarName := "sparcala.jar",
    assembly / assemblyMergeStrategy := {
      case PathList("META-INF", "services", xs @ _*) => MergeStrategy.filterDistinctLines
      case PathList("META-INF", xs @ _*)             => MergeStrategy.discard
      case "application.conf"                        => MergeStrategy.concat
      case _                                         => MergeStrategy.first
    }
  )

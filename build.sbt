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
ThisBuild / scalafixDependencies += "org.typelevel" %% "typelevel-scalafix" % "0.2.0"

Global / onChangedBuildSource := ReloadOnSourceChanges

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

val Scala2 = "2.13.11"
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

val SparkVersion = "3.5.1"
lazy val Spark = Seq("spark-core", "spark-sql", "spark-sql-kafka-0-10")
  .map("org.apache.spark" %% _)
  .map(_ % SparkVersion % "provided")

lazy val root = (project in file("."))
  .aggregate(sparcala)
  .settings(
    name := "datatrappa",
    scalafixOnCompile := true
  )

lazy val sparcala = (project in file("sparcala"))
  .settings(scala2Settings)
  .settings(name := "sparcala")
  .settings(
    // libraryDependencies ++= Spark ++ Frameless,
    libraryDependencies ++= Spark,
    assembly / mainClass := Some("data.cartel.sparcala.Sparcala"),
    assembly / assemblyJarName := "sparcala.jar",
    assembly / assemblyShadeRules := Seq(
      ShadeRule.rename("shapeless.**" -> "new_shapeless.@1").inAll,
      ShadeRule.rename("cats.kernel.**" -> s"new_cats.kernel.@1").inAll
    ),
    assembly / assemblyMergeStrategy := {
      case PathList("META-INF", xs @ _*) => MergeStrategy.discard
      case x                             => MergeStrategy.first
    }
  )

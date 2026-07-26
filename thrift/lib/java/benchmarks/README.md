# FBThrift Java benchmarks

Build the benchmark JAR from the Java reactor with JDK 21 or 25:

```sh
mvn -f thrift/lib/java/pom.xml -pl benchmarks -am package -DskipTests
java -jar thrift/lib/java/benchmarks/target/fbthrift-java-benchmarks.jar
```

The OSS module compiles all portable JMH and load-generator sources. It
intentionally excludes `SRProxyClient`, which requires Meta's internal
Service Router proxy client. `runtime/benchmark/StatsBenchmark.java` is also
Meta-only because it compares against `com.facebook.titan.stats`.

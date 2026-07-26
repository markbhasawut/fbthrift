# Android Lite Java runtime

`android_lite` is the dependency-free Java runtime for constrained Android
clients. It supports sources generated with the public generator name:

```sh
thrift1 --gen android_lite path/to/schema.thrift
```

The IDL must declare an Android namespace for generated packages:

```thrift
namespace android com.example.api
```

The generator writes Java sources below `gen-android/`. Add those sources and
the runtime JAR to the Android application. The historical implementation name
`android` remains accepted, but new builds should use `android_lite`.

## Build and test

Maven is the authoritative build. Use JDK 21 or JDK 25, matching the parent
FBThrift Java reactor; the resulting Android Lite runtime remains compatible
with Java 8 bytecode.

```sh
mvn -f thrift/lib/java/pom.xml -pl ../android_lite -am verify
```

The runtime JAR is written to
`thrift/lib/android_lite/target/fbthrift-android-lite.jar`. Run `mvn package`
when tests are not required, or `mvn javadoc:javadoc` to build API
documentation.

The former Ant build targeted Java 5 and predated the current JUnit 5 test
suite. It has been removed rather than retained as a second, untested build
definition.

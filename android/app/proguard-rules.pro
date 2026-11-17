# Flutter loads plugins reflectively. The Flutter Gradle plugin also applies
# packages/flutter_tools/gradle/flutter_proguard_rules.pro on release builds.
-if class * implements io.flutter.embedding.engine.plugins.FlutterPlugin
-keep,allowshrinking,allowobfuscation class <1>

# The embedding references Play Feature Delivery even when deferred components
# are off. Those classes are not on the classpath, and R8 treats the missing
# references as errors unless they are ignored.
-dontwarn com.google.android.play.core.**

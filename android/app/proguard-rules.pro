# The embedding references Play Feature Delivery even when deferred components
# are off. Those classes are not on the classpath, and R8 treats the missing
# references as errors unless they are ignored. The Flutter Gradle plugin
# already ships the plugin keep rules.
-dontwarn com.google.android.play.core.**

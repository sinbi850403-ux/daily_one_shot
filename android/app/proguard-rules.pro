# Flutter & Dart
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Play Core (AAB split install)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Google Mobile Ads
-keep class com.google.android.gms.ads.** { *; }

# SQLite / Drift
-keep class org.sqlite.** { *; }
-keep class org.sqlite.database.** { *; }

# Kotlin
-keep class kotlin.** { *; }
-keepclassmembers class **$WhenMappings { <fields>; }

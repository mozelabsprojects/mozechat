# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class plugins.flutter.io.**  { *; }

# Firebase / Firestore
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Play Core / Flutter Embedding (Fix R8 Missing Classes)
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.**

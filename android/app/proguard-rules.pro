# Keep ML Kit classes
-keep class com.google.mlkit.** { *; }

# Suppress warnings for optional ML Kit scripts
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Keep flutter_local_notifications receivers (R8 puede eliminarlos en release)
-keep class com.dexterous.** { *; }
-keepclassmembers class com.dexterous.** { *; }
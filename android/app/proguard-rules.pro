# Flutter & Android embedding rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Google ML Kit Text Recognition (Latin bundled; ignore optional non-Latin scripts)
-keep class com.google.mlkit.vision.text.** { *; }
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-dontwarn com.google.android.gms.internal.mlkit_vision_text_common.**

# CameraX / Mobile Scanner / Barcode scanning
-keep class dev.steenbakker.mobile_scanner.** { *; }
-keep class com.google.mlkit.vision.barcode.** { *; }
-keep class androidx.camera.** { *; }

# Firebase Auth & Google Sign-In / Credential Manager
-keep class com.google.firebase.** { *; }
-keep class androidx.credentials.** { *; }
-keep class com.google.android.gms.auth.** { *; }
-dontwarn javax.annotation.**

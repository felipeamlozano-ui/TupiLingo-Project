# ─── TupiLingo ProGuard / R8 Hardening Rules ─────────────────────────────────

# 1. Remoção completa de logs em builds de Release (Prevenção de vazamento de credenciais e rotas)
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
    public static int i(...);
    public static int w(...);
    public static int e(...);
}

# 2. Preservação de interfaces JNI do Flutter Engine
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# 3. Preservação de classes criptográficas do AndroidX Security (EncryptedSharedPreferences / Keystore)
-keep class androidx.security.crypto.** { *; }
-dontwarn androidx.security.crypto.**

# 4. Suporte a Protocol Buffers (caso usado nativamente no Android)
-keepclassmembers class * extends com.google.protobuf.GeneratedMessageLite {
    <fields>;
}
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**

# 5. Ofuscação de nomes de classes e métodos de plugins nativos
-repackageclasses 'com.tupilingo.obf'
-allowaccessmodification

# 6. Preservação do Google Play Core (In-App Updates, Reviews, etc.)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**


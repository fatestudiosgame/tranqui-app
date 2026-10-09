# ========================================
# OKHTTP Y NETWORKING
# ========================================

# OkHttp platform - Ignorar clases opcionales de plataformas SSL/TLS
# Estas clases son cargadas dinámicamente por OkHttp pero no son obligatorias
-dontwarn okhttp3.internal.platform.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# Mantener clases de OkHttp
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okio.**
-dontwarn javax.annotation.**
-dontwarn sun.misc.Unsafe
-dontwarn java.lang.ClassValue

# Gson (usado por varias librerías)
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepattributes Signature
-keepattributes *Annotation*

# ========================================
# APKLIS LICENSE VALIDATOR
# ========================================

# Mantener todas las clases del plugin de Apklis
-keep class cu.uci.android.apklis.** { *; }
-keep class cu.uci.apklislicensevalidator.** { *; }
-keep class com.example.apklis_license_validator.** { *; }
-keep class * implements cu.uci.android.apklis.** { *; }
-keep class * extends cu.uci.android.apklis.** { *; }

# Mantener ContentProviders de Apklis
-keep class cu.uci.android.apklis.provider.** { *; }

# Mantener modelos de datos del validador
-keep class * extends com.google.gson.reflect.TypeToken
-keepclasseswithmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# ========================================
# FIREBASE Y FCM
# ========================================

-keep class com.google.firebase.** { *; }
-keep class io.flutter.plugins.firebase.** { *; }
-keepnames class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Mantener servicios de mensajería
-keep class com.google.firebase.messaging.** { *; }
-keep class * extends com.google.firebase.messaging.FirebaseMessagingService

# ========================================
# FLUTTER PLUGINS Y PLATFORM
# ========================================

-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Geolocator
-keep class com.baseflow.geolocator.** { *; }
-keep class com.baseflow.location_permissions.** { *; }

# Path Provider
-keep class io.flutter.plugins.pathprovider.** { *; }

# Shared Preferences
-keep class com.example.shared_preferences.** { *; }
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# Connectivity Plus
-keep class dev.fluttercommunity.plus.connectivity.** { *; }

# URL Launcher
-keep class io.flutter.plugins.urllauncher.** { *; }

# Package Info Plus
-keep class dev.fluttercommunity.plus.packageinfo.** { *; }

# Share Plus
-keep class dev.fluttercommunity.plus.share.** { *; }

# App Links
-keep class com.llfbandit.app_links.** { *; }

# Image Picker / Camera
-keep class io.flutter.plugins.imagepicker.** { *; }

# Hive (cache de mapas)
-keep class com.hive.** { *; }
-keep class * extends com.hive.StorageAdapter

# Flutter Map
-keep class com.johnkil.print.** { *; }

# ========================================
# ANDROIDX Y LIFECYCLE
# ========================================

-keep class androidx.lifecycle.DefaultLifecycleObserver
-keep class androidx.lifecycle.** { *; }
-keepclassmembers class * implements androidx.lifecycle.LifecycleObserver {
    <methods>;
}

# Mantener ViewModels
-keep class * extends androidx.lifecycle.ViewModel {
    <init>();
}

# ========================================
# ENUMS Y CLASES ESPECIALES
# ========================================

-keepclassmembers class * extends java.lang.Enum {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ========================================
# PARCELABLE Y SERIALIZABLE
# ========================================

-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    !private <fields>;
    !private <methods>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# ========================================
# MÉTODOS NATIVOS Y JNI
# ========================================

-keepclasseswithmembernames class * {
    native <methods>;
}

-keepclasseswithmembernames class * {
    public <init>(android.content.Context, android.util.AttributeSet);
}

-keepclasseswithmembernames class * {
    public <init>(android.content.Context, android.util.AttributeSet, int);
}

# ========================================
# ATRIBUTOS NECESARIOS
# ========================================

-keepattributes SourceFile,LineNumberTable
-keepattributes InnerClasses,EnclosingMethod
-keepattributes Exceptions
-keepattributes MethodParameters

# ========================================
# REGLAS PARA NO ROMPER R8
# ========================================

# No warning por clases que no se usan pero están referenciadas
-dontwarn java.lang.invoke.StringConcatFactory
-dontwarn javax.annotation.**
-dontwarn kotlin.Unit
-dontwarn kotlinx.coroutines.**
-dontwarn com.google.android.play.core.**

# Mantener el entry point de Flutter
-keep class io.flutter.embedding.android.FlutterActivity
-keep class io.flutter.embedding.engine.** { *; }
-keep class io.flutter.embedding.android.** { *; }
# Flutter specific
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Flutter Play Core (deferred components) - don't warn if missing
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# Play Core (deferred components) - not used but referenced by Flutter
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# SQLCipher / SQLite
-keep class net.sqlcipher.** { *; }
-keep class net.sqlcipher.database.** { *; }
-keep class org.sqlite.** { *; }
-keepclassmembers class net.sqlcipher.** { *; }

# Drift / Moor database
-keep class * extends GeneratedDatabase { *; }
-keep class * extends Table { *; }
-keep class * extends DataClass { *; }
-keep class **.database.** { *; }
-keep class **.tables.** { *; }
-keep class **.daos.** { *; }

# Keep all serialization-related members
-keepclassmembers class * {
    @drift.Annotation <methods>;
    @moor.Annotation <methods>;
}

# Keep JSON serialization classes
-keep class **.g.dart { *; }
-keep class **.freezed.dart { *; }

# Riverpod providers
-keep class * implements ProviderBase { *; }
-keepclassmembers class * implements ProviderBase {
    <methods>;
}

# UUID
-keep class com.uuid.** { *; }

# Encryption
-keep class **.encryption.** { *; }
-keepclassmembers class **.encryption.** { *; }

# Keep all Parcelable classes (for Android)
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep Serializable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Remove logging in release builds
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
}

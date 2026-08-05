# Keep source file attrs — required by commons-compress ZipFile (youtubedl-android #234).
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# youtubedl-android + bundled FFmpeg helpers
-keep class com.yausername.** { *; }
-dontwarn com.yausername.**

# Jackson used by YoutubeDL.getInfo / internal parsing
-keepattributes *Annotation*,EnclosingMethod,Signature,InnerClasses
-keep class com.fasterxml.jackson.** { *; }
-dontwarn com.fasterxml.jackson.**

# Apache Commons Compress / IO used during Python + FFmpeg unzip
-keep class org.apache.commons.compress.** { *; }
-keep class org.apache.commons.io.** { *; }
-dontwarn org.apache.commons.**

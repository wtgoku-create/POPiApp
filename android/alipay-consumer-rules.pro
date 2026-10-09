# Preserve the Alipay SDK's reflection and IPC entry points without global flags.
-keep class com.alipay.** { *; }
-keep class org.json.alipay.** { *; }
-keep class com.ta.utdid2.** { *; }
-keep class com.ut.device.** { *; }
-keepattributes Exceptions,InnerClasses,Signature

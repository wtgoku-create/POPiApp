# The SDK parses callback metadata with Gson before delivering authorization.
-keepattributes Signature,*Annotation*
-keep class com.bytedance.sdk.open.aweme.commonbase.extradata.** { *; }

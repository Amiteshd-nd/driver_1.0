# Android `AndroidManifest.xml` additions

`flutter create .` generates `android/app/src/main/AndroidManifest.xml`. Add the permissions below above `<application>`,
and the intent filter / service bits inside it. Android shows system permission dialogs without custom strings;
the *why* lives on our onboarding cards (DESIGN.md §8), so the in-app copy is listed next to each permission for reference.

```xml
<!-- Location: "to measure distance and notice when you explore somewhere new" -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<!-- Background: "so a run keeps recording with the screen off" (requested separately, after while-in-use) -->
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />

<!-- Foreground service for the geolocator notification during a run -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

<!-- Motion & fitness + activity recognition: "to count steps, feel your footfall rhythm and tell running from a bus ride" -->
<uses-permission android:name="android.permission.ACTIVITY_RECOGNITION" />
<uses-permission android:name="com.google.android.gms.permission.ACTIVITY_RECOGNITION" />
<uses-permission android:name="android.permission.HIGH_SAMPLING_RATE_SENSORS" />

<!-- Health Connect (health package): "to read heart rate and running workouts; we keep an average and a peak per run" -->
<uses-permission android:name="android.permission.health.READ_HEART_RATE" />
<uses-permission android:name="android.permission.health.READ_STEPS" />
<uses-permission android:name="android.permission.health.READ_EXERCISE" />
<uses-permission android:name="android.permission.health.READ_DISTANCE" />
<uses-permission android:name="android.permission.health.READ_HEALTH_DATA_IN_BACKGROUND" />

<!-- Health Connect must be visible to the app on Android 13 and below -->
<queries>
  <package android:name="com.google.android.apps.healthdata" />
  <intent>
    <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />
  </intent>
</queries>
```

Inside `<application>`:

```xml
<!-- Magic-link redirect: supabase emailRedirectTo = flyingcobra://login -->
<activity android:name=".MainActivity" ...>
  ...
  <intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="flyingcobra" android:host="login" />
  </intent-filter>
</activity>

<!-- Health Connect permissions rationale (required by the health package) -->
<activity-alias
  android:name="ViewPermissionUsageActivity"
  android:exported="true"
  android:targetActivity=".MainActivity"
  android:permission="android.permission.START_VIEW_PERMISSION_USAGE">
  <intent-filter>
    <action android:name="android.intent.action.VIEW_PERMISSION_USAGE" />
    <category android:name="android.intent.category.HEALTH_PERMISSIONS" />
  </intent-filter>
</activity-alias>
```

Also:
- `android/app/build.gradle`: `minSdkVersion 26` (Health Connect), `compileSdkVersion 34`, `targetSdkVersion 34`.
- `MainActivity` must extend `FlutterFragmentActivity` (the `health` package requires it for Health Connect permission dialogs).
- The geolocator foreground service is declared by the plugin; `FOREGROUND_SERVICE_LOCATION` is mandatory on API 34.
- Request order in-app (see `features/run/permissions.dart`): fine location first, background location afterwards from the trust centre, never both in one dialog (Play policy).

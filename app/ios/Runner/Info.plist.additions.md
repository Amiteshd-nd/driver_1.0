# iOS `Info.plist` additions

`flutter create .` generates `ios/Runner/Info.plist`. Add the keys below inside the top-level `<dict>`.
Purpose strings follow DESIGN.md §8: *what*, *why*, *what we store*, no pressure.

```xml
<!-- Location: distance, route, explorer animals -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>Flying Cobra uses your location while you run to measure distance and notice when you explore somewhere new. Your route is stored privately and is visible to you alone.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Allowing location in the background lets a run keep recording with the screen off. Flying Cobra reads location during a run you started, never between runs. Your route stays private to you.</string>

<!-- Motion & fitness: steps and footfall rhythm (two numbers per run, never raw samples) -->
<key>NSMotionUsageDescription</key>
<string>Flying Cobra counts steps and senses the rhythm of your footfall to confirm a run was a run. We keep a step count and two rhythm numbers per run — never raw sensor data.</string>

<!-- Health: heart rate (read) and workouts for the optional import -->
<key>NSHealthShareUsageDescription</key>
<string>Flying Cobra can read heart rate and running workouts from Health to grade effort and import runs you recorded elsewhere. We keep an average and a peak heart rate per run. Nothing is written back.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>Flying Cobra does not write to Health.</string>

<!-- Background location so a run survives the screen turning off -->
<key>UIBackgroundModes</key>
<array>
  <string>location</string>
</array>

<!-- Magic-link redirect (supabase emailRedirectTo: flyingcobra://login) -->
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>flyingcobra</string>
    </array>
  </dict>
</array>
```

Also:
- Xcode → Runner target → *Signing & Capabilities* → add **HealthKit** (the `health` package needs the entitlement) and **Background Modes → Location updates**.
- `ios/Podfile`: set `platform :ios, '13.0'` or higher (health 11 and geolocator 13 require it). In the `post_install` block, add the permission_handler macros so the unused permissions are compiled out:
  ```ruby
  target.build_configurations.each do |config|
    config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)',
      'PERMISSION_LOCATION=1', 'PERMISSION_SENSORS=1', 'PERMISSION_NOTIFICATIONS=1']
  end
  ```
- Notifications: `permission_handler` asks via `Permission.notification`; no plist key is needed.
- Activity recognition (`flutter_activity_recognition`) uses CoreMotion and is covered by `NSMotionUsageDescription`.

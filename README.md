# ✈️ SkyLink — Offline Flight Chat App

Chat with friends on the same flight via Bluetooth & WiFi Direct.
**Zero internet required.** Works at 35,000 ft.

---

## 📁 Project Structure

```
skylink/
├── lib/
│   ├── main.dart                    ← App entry point & splash
│   ├── models/
│   │   └── message.dart             ← Message & Peer data models
│   ├── services/
│   │   └── nearby_service.dart      ← Bluetooth/WiFi Direct logic
│   └── screens/
│       ├── onboarding_screen.dart   ← Name & emoji setup
│       ├── home_screen.dart         ← Peer discovery list
│       └── chat_screen.dart         ← 1-on-1 chat UI
├── android/
│   └── app/
│       ├── build.gradle             ← Android build config
│       └── src/main/AndroidManifest.xml
├── ios/
│   └── Runner/
│       └── Info.plist               ← iOS permissions
└── pubspec.yaml                     ← Dependencies
```

---

## 🛠️ STEP 1 — Install Flutter

### On macOS
```bash
# Install via Homebrew
brew install --cask flutter

# Or download manually from:
# https://docs.flutter.dev/get-started/install/macos

# Verify installation
flutter doctor
```

### On Windows
```powershell
# Download Flutter SDK from:
# https://docs.flutter.dev/get-started/install/windows

# Extract to C:\flutter
# Add C:\flutter\bin to your PATH environment variable

# Verify
flutter doctor
```

### On Linux
```bash
sudo snap install flutter --classic
flutter doctor
```

> ✅ Fix any issues `flutter doctor` reports before continuing.

---

## 🛠️ STEP 2 — Install Android Studio (for Android builds)

1. Download from https://developer.android.com/studio
2. Open Android Studio → SDK Manager → install:
   - Android SDK Platform 34
   - Android SDK Build-Tools 34
   - Android Emulator (optional)
3. Run `flutter doctor --android-licenses` and accept all licenses

---

## 🛠️ STEP 3 — Install Xcode (for iOS builds — Mac only)

```bash
# Install Xcode from the Mac App Store, then:
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

Install CocoaPods:
```bash
sudo gem install cocoapods
# or
brew install cocoapods
```

---

## 🛠️ STEP 4 — Create the Flutter Project

```bash
# Create project
flutter create skylink --org com.skylink --platforms android,ios

# Enter the project folder
cd skylink
```

---

## 🛠️ STEP 5 — Replace All Project Files

Copy all files from this repo into your `skylink/` folder,
**overwriting** the defaults Flutter created.

Files to replace:
```
pubspec.yaml
lib/main.dart
lib/models/message.dart
lib/services/nearby_service.dart
lib/screens/onboarding_screen.dart
lib/screens/home_screen.dart
lib/screens/chat_screen.dart
android/app/build.gradle
android/app/src/main/AndroidManifest.xml
ios/Runner/Info.plist
```

---

## 🛠️ STEP 6 — Install Dependencies

```bash
flutter pub get
```

You should see all packages resolve successfully.

---

## 🛠️ STEP 7 — Android Setup

### 7a. Set the App ID
Open `android/app/build.gradle` and confirm:
```groovy
defaultConfig {
    applicationId "com.skylink.chat"
    minSdkVersion 21          // Required for Nearby Connections
    targetSdkVersion 34
}
```

### 7b. Enable Kotlin (if not already)
Open `android/build.gradle` (root level) and confirm:
```groovy
buildscript {
    ext.kotlin_version = '1.9.0'
    dependencies {
        classpath 'com.android.tools.build:gradle:8.1.0'
        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version"
    }
}
```

### 7c. Enable Multidex (if you hit 64K method limit)
In `android/app/build.gradle` defaultConfig, add:
```groovy
multiDexEnabled true
```
And in dependencies:
```groovy
implementation 'androidx.multidex:multidex:2.0.1'
```

---

## 🛠️ STEP 8 — iOS Setup

### 8a. Install CocoaPods dependencies
```bash
cd ios
pod install
cd ..
```

### 8b. Open in Xcode and set Team
```bash
open ios/Runner.xcworkspace
```
- Select **Runner** in the file tree
- Go to **Signing & Capabilities**
- Set your **Team** (your Apple ID or paid developer account)
- Set **Bundle Identifier** to `com.skylink.chat`

### 8c. Multipeer Connectivity capability
In Xcode:
- Runner → Signing & Capabilities → **+ Capability**
- Add **Multipeer Connectivity**

> ⚠️ The `nearby_connections` package uses Multipeer Connectivity on iOS.
> Without this, peer discovery won't work on iPhone.

---

## 🛠️ STEP 9 — Run the App

### On a physical Android device:
```bash
# Enable Developer Options on your phone:
# Settings → About Phone → tap Build Number 7 times
# Settings → Developer Options → enable USB Debugging

# Connect via USB, then:
flutter devices          # confirm your device appears
flutter run              # builds and installs on device
```

### On a physical iPhone:
```bash
# Trust your Mac on the iPhone when prompted
flutter devices
flutter run
```

### Release build for Android (.apk to share with friends):
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
# Send this .apk file to all your friends via WhatsApp/email
# They install it by enabling "Install from Unknown Sources"
```

### Release build for iOS (.ipa):
```bash
flutter build ipa
# Requires paid Apple Developer account ($99/yr) to distribute outside TestFlight
# For testing with friends, use Xcode → Product → Archive → Distribute (Ad Hoc)
```

---

## 📱 STEP 10 — How to Use SkyLink

1. **All friends install the app** — share the `.apk` on Android,
   or use TestFlight/Ad Hoc on iOS
2. **Everyone opens SkyLink** before boarding or during the flight
3. **Enter your name and pick an emoji avatar**
4. **The app automatically scans** for nearby SkyLink users
   via Bluetooth + WiFi Direct (no internet needed)
5. **Tap a friend's name** to connect → then **Chat!**
6. All 5 friends can chat individually with each other —
   the app supports up to ~8 simultaneous peers

---

## ⚡ How It Works Technically

```
Friend A's Phone ←—Bluetooth/WiFi Direct—→ Friend B's Phone
                                         ←—→ Friend C's Phone
                                         ←—→ Friend D's Phone

Protocol: Google Nearby Connections API (P2P_CLUSTER strategy)
Transport: Bluetooth Classic + BLE + WiFi Direct (auto-selects best)
Range: ~100 meters (more than enough for a plane cabin)
Data: JSON-encoded messages as byte payloads
Encryption: Built-in by Nearby Connections API
```

---

## 🔧 Troubleshooting

| Problem | Fix |
|---|---|
| `flutter doctor` shows missing Android SDK | Install Android Studio + SDK |
| `pod install` fails | Run `sudo gem install cocoapods` first |
| App crashes on launch (Android) | Check you granted Location + Bluetooth permissions |
| Peers not showing up | Both phones must have the app open + BT + Location on |
| iOS build fails "no team" | Set your Apple ID in Xcode Signing & Capabilities |
| `minSdkVersion` error | Ensure `minSdkVersion 21` in android/app/build.gradle |
| Messages not sending | Peer must be "Connected" (green dot) before you can chat |

---

## 📦 Dependencies Explained

| Package | Purpose |
|---|---|
| `nearby_connections` | Core P2P — Bluetooth + WiFi Direct |
| `permission_handler` | Request BT/Location permissions at runtime |
| `google_fonts` | Outfit font for the UI |
| `flutter_animate` | Smooth animations and transitions |
| `shared_preferences` | Save your name/emoji between sessions |
| `uuid` | Generate unique message IDs |
| `intl` | Format timestamps in chat |
| `vibration` | Haptic feedback on new messages |

---

## 🎨 App Screens

| Screen | Description |
|---|---|
| **Splash** | Animated logo, checks if onboarding is done |
| **Onboarding** | Pick emoji avatar + enter your name |
| **Home** | Live radar showing all nearby SkyLink users |
| **Chat** | Full messaging UI with timestamps, bubbles, unread badges |

---

## 🚀 Future Improvements (ideas)

- Group chat (broadcast to all connected peers)
- Send photos (image payload support)
- Reactions / emoji replies
- Seat number display
- Message encryption UI (lock icon)
- Sound notifications

---

## ✅ Quick Checklist Before the Flight

- [ ] All friends have installed SkyLink
- [ ] Everyone has opened the app at least once (sets up their name)
- [ ] Bluetooth is ON on all phones
- [ ] Location is ON (needed by Android for BT scanning)
- [ ] WiFi is ON (for WiFi Direct fallback)
- [ ] Phone is NOT in Airplane Mode (turn BT back on manually after)

> 💡 Tip: On most phones, you can enable Airplane Mode and then
> manually re-enable Bluetooth & WiFi. SkyLink will still work
> because it doesn't use the cellular network at all!

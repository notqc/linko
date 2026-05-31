# Linko

<p align="center">
  <h3 align="center">Come. Connect. Chat.</h3>
  <p align="center">
    Offline peer-to-peer messaging powered by Bluetooth and WiFi Direct.
  </p>
</p>

---

## 📖 Overview

Linko is an offline peer-to-peer messaging application built with Flutter. It enables users to communicate directly over Bluetooth and WiFi Direct without requiring internet access, a SIM card, or any external server.

Using Google's Nearby Connections API, the application discovers nearby devices running Linko and establishes encrypted peer-to-peer connections via Bluetooth and WiFi Direct. All messages are encrypted using RSA-2048 before transmission and stored locally on the device using SQLite.

The application is designed for everyday use in environments where internet access is unavailable or unreliable — including remote areas, flights, events, and institutional networks with restricted access.

---

## 📑 Table of Contents

* [Overview](#-overview)
* [Features](#-features)
* [Tech Stack](#-tech-stack)
* [Project Structure](#-project-structure)
* [Architecture](#-architecture)
* [Encryption](#-encryption)
* [PIN Verification](#-pin-verification)
* [Mesh Relay](#-mesh-relay)
* [Chat Persistence](#-chat-persistence)
* [Getting Started](#-getting-started)
* [Build and Distribution](#-build-and-distribution)
* [Permissions](#-permissions)
* [Device Specifications](#-device-specifications)
* [Known Limitations](#-known-limitations)
* [Roadmap](#-roadmap)
* [License](#-license)

---

## ✨ Features

| Feature               | Description                                                  |
| --------------------- | ------------------------------------------------------------ |
| Offline Communication | No internet, SIM, or external server required                |
| RSA-2048 Encryption   | All messages encrypted end-to-end before transmission        |
| PIN Verification      | Both devices must confirm a matching PIN before connecting   |
| Mesh Relay            | Messages route through intermediate devices up to 5 hops     |
| Chat Persistence      | Messages saved locally using SQLite and survive app restarts |
| Auto Discovery        | Nearby devices running Linko are detected automatically      |
| Multi-peer Support    | Connect with up to 8 devices simultaneously                  |
| Cross-session History | Previous conversations accessible on the home screen         |

---

## 🛠 Tech Stack

| Layer              | Technology                    | Purpose                                 |
| ------------------ | ----------------------------- | --------------------------------------- |
| Framework          | Flutter 3.44 (Dart)           | Cross-platform mobile development       |
| P2P Transport      | Google Nearby Connections API | Bluetooth and WiFi Direct communication |
| Encryption         | RSA-2048 via pointycastle     | End-to-end message encryption           |
| Local Database     | SQLite via sqflite            | Persistent chat storage                 |
| UI Animations      | flutter_animate               | Transitions and feedback animations     |
| Typography         | Google Fonts – Outfit         | Consistent visual language              |
| Unique Identifiers | uuid                          | Message and device ID generation        |
| Storage            | shared_preferences            | User profile persistence                |
| Time Formatting    | intl                          | Human-readable timestamps               |

---

## 📂 Project Structure

```text
lib/
├── main.dart
├── models/
│   └── message.dart
│       └── Data models for Message and Peer
│
├── services/
│   └── nearby_service.dart
│       └── Core P2P logic, encryption, relay, PIN
│
├── utils/
│   ├── rsa_helper.dart
│   │   └── RSA key generation, encryption, decryption
│   └── database_helper.dart
│       └── SQLite operations for message persistence
│
├── screens/
│   ├── onboarding_screen.dart
│   │   └── First-time user setup
│   ├── home_screen.dart
│   │   └── Peer discovery and recent conversations
│   └── chat_screen.dart
│       └── Messaging interface
│
└── widgets/
    └── pin_dialog.dart
        └── PIN verification dialog
```

---

## 🏗 Architecture

Linko follows a **Service-Screen Separation Pattern**.

Screens handle only UI rendering and user interaction. All networking, encryption, and data logic are handled exclusively by `NearbyService` and utility classes.

```text
Screens (UI Layer)
        │
        ▼
NearbyService (Logic Layer)
        │
 ├── RSAHelper          (Encryption)
 ├── DatabaseHelper     (Persistence)
 └── Nearby Connections (Transport)
```

### Data Flow — Sending a Message

```text
User types a message and taps Send
        │
        ▼
NearbyService retrieves recipient public key
        │
        ▼
Message encrypted using RSA-2048 OAEP
        │
        ▼
Encrypted payload converted to JSON bytes
        │
        ▼
Nearby Connections transmits payload
        │
        ▼
Message stored in SQLite
        │
        ▼
UI updates with sent message bubble
```

### Data Flow — Receiving a Message

```text
onPayloadReceived callback fires
        │
        ▼
Bytes decoded into JSON
        │
        ▼
Message type identified
        │
        ▼
Encrypted content decrypted
        │
        ▼
Stored in SQLite
        │
        ▼
UI callback updates chat screen
```

---

## 🔐 Encryption

Linko uses **RSA-2048 with OAEP padding** for all message encryption.

### Key Generation

Each device generates an RSA-2048 key pair on first launch. The key pair is stored locally in `shared_preferences` and persists across sessions.

**The private key never leaves the device.**

### Key Exchange

When two devices connect, they exchange public keys via an encrypted handshake before any messages are sent. This ensures that all subsequent messages can only be decrypted by the intended recipient.

### Encryption Process

```text
Sender:
plaintext
    ↓
RSA Encrypt (Recipient Public Key)
    ↓
ciphertext
    ↓
Transmit

Recipient:
ciphertext
    ↓
RSA Decrypt (Own Private Key)
    ↓
plaintext
    ↓
Display
```

### Security Properties

* No third party, including relay devices, can decrypt message content.
* Private keys are stored only on the originating device.
* All transmitted data remains ciphertext while in transit.
* Nearby Connections provides an additional transport-level encryption layer.

---

## 🔢 PIN Verification

PIN verification prevents unauthorized devices from initiating a chat session.

### Process

```text
Device A requests connection to Device B
            ↓
Transport connection established
            ↓
Both devices display same 6-digit PIN
            ↓
Users verify PIN verbally
            ↓
Confirm or Reject
            ↓
Chat session opens only after mutual confirmation
```

This approach mirrors the pairing model used by Bluetooth headsets and prevents a nearby stranger with Linko installed from silently connecting.

---

## 🌐 Mesh Relay

Mesh relay extends the effective range of Linko beyond direct Bluetooth or WiFi Direct coverage.

### Direct Connection

```text
Device A <--------> Device B
```

### Relayed Connection

```text
Device A ----> Device C ----> Device B

(Device C relays encrypted data only)
```

### Design Principles

* Messages are relayed as encrypted ciphertext only.
* Intermediate devices cannot decrypt relayed content.
* Each message carries a TTL (Time To Live) starting at 5.
* TTL decreases at every hop.
* Messages reaching TTL 0 are discarded.
* Visited lists prevent routing loops.
* Deduplicated message IDs prevent duplicate deliveries.

---

## 💾 Chat Persistence

All messages are stored locally in an SQLite database using the `sqflite` package.

### Storage Details

* Database location: On-device only, within app private storage.
* Messages are stored in decrypted form after receipt.
* Chat history persists across sessions and app restarts.
* Uninstalling the application permanently removes all data.
* No information is transmitted to any cloud service or external server.

### Database Schema

#### messages

```text
id          TEXT PRIMARY KEY
peerId      TEXT
peerName    TEXT
senderId    TEXT
senderName  TEXT
content     TEXT
timestamp   INTEGER
isMe        INTEGER
isRelayed   INTEGER
```

#### peers

```text
id          TEXT PRIMARY KEY
name        TEXT
emoji       TEXT
lastSeen    INTEGER
```

---

## 🚀 Getting Started

### Prerequisites

* Flutter SDK 3.44 or higher
* Android SDK 36
* Android device running Android 5.0 (API 21) or higher
* Bluetooth and Location enabled

### Installation

```bash
git clone https://github.com/notqc/linko.git
cd linko
flutter pub get
flutter run
```

### First Use

1. Open Linko.
2. Enter a display name and select an avatar.
3. Grant Bluetooth and Location permissions.
4. The home screen automatically starts scanning for nearby devices.

---

## 📦 Build and Distribution

### Debug Build

```bash
flutter run
```

### Release APK

```bash
flutter build apk --release
```

Output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

### Installing on Another Device

1. Transfer the APK via WhatsApp, email, or USB.
2. Open the APK file on the target device.
3. Enable **Install from Unknown Sources** if prompted.
4. Install and launch Linko.

---

## 🔑 Permissions

### Android

| Permission           | Purpose                                         |
| -------------------- | ----------------------------------------------- |
| BLUETOOTH            | Classic Bluetooth (Android 11 and below)        |
| BLUETOOTH_SCAN       | Scan for nearby Bluetooth devices (Android 12+) |
| BLUETOOTH_ADVERTISE  | Broadcast device presence (Android 12+)         |
| BLUETOOTH_CONNECT    | Connect to discovered devices (Android 12+)     |
| ACCESS_FINE_LOCATION | Required by Android for Bluetooth scanning      |
| NEARBY_WIFI_DEVICES  | WiFi Direct peer discovery (Android 13+)        |
| CHANGE_WIFI_STATE    | Enable WiFi Direct connections                  |
| VIBRATE              | Haptic feedback on message receipt              |

---

## 📱 Device Specifications

| Specification              | Value                  |
| -------------------------- | ---------------------- |
| Minimum Android Version    | Android 5.0 (API 21)   |
| Target Android Version     | Android 16 (API 36)    |
| Maximum Simultaneous Peers | 8 Devices              |
| Effective Range            | ~100 metres (open air) |
| Maximum Relay Hops         | 5                      |
| Encryption Standard        | RSA-2048 with OAEP     |
| Storage Type               | On-device SQLite       |
| Internet Requirement       | None                   |

---

## ⚠️ Known Limitations

* iOS support is not included in the current release.
* Range depends on environmental conditions and interference.
* RSA-2048 introduces a small delay during initial key generation and exchange.
* Chat history is permanently lost if the application is uninstalled.
* Devices must have Linko open and running to remain discoverable.

---

## 🗺 Roadmap

* Group broadcast messaging
* Image and file sharing
* Message read receipts
* Sound and vibration notification settings
* iOS support via TestFlight
* Export chat history as a text file
* Dark and light theme toggle

---

## 📄 License

This project is licensed under the MIT License.

You are free to use, modify, and distribute this software for any purpose, provided the original license notice is retained.

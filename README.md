# Linko

**Come. Connect. Chat.**

Linko is an offline peer-to-peer messaging application built with Flutter. It enables
users to communicate directly over Bluetooth and WiFi Direct without requiring internet
access, a SIM card, or any external server.

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Architecture](#architecture)
- [Encryption](#encryption)
- [PIN Verification](#pin-verification)
- [Mesh Relay](#mesh-relay)
- [Chat Persistence](#chat-persistence)
- [Getting Started](#getting-started)
- [Build and Distribution](#build-and-distribution)
- [Permissions](#permissions)
- [Device Specifications](#device-specifications)
- [Known Limitations](#known-limitations)
- [Roadmap](#roadmap)
- [License](#license)

---

## Overview

Linko eliminates the dependency on internet infrastructure for communication.
Using Google's Nearby Connections API, the application discovers nearby devices
running Linko and establishes encrypted peer-to-peer connections via Bluetooth
and WiFi Direct. All messages are encrypted using RSA-2048 before transmission
and stored locally on the device using SQLite.

The application is designed for everyday use in environments where internet
access is unavailable or unreliable — including remote areas, flights, events,
and institutional networks with restricted access.

---

## Features

| Feature | Description |
|---|---|
| Offline Communication | No internet, SIM, or external server required |
| RSA-2048 Encryption | All messages encrypted end-to-end before transmission |
| PIN Verification | Both devices must confirm a matching PIN before connecting |
| Mesh Relay | Messages route through intermediate devices up to 5 hops |
| Chat Persistence | Messages saved locally using SQLite, survives app restarts |
| Auto Discovery | Nearby devices running Linko are detected automatically |
| Multi-peer Support | Connect with up to 8 devices simultaneously |
| Cross-session History | Previous conversations accessible on the home screen |

---

## Tech Stack

| Layer | Technology | Purpose |
|---|---|---|
| Framework | Flutter 3.44 (Dart) | Cross-platform mobile development |
| P2P Transport | Google Nearby Connections API | Bluetooth and WiFi Direct communication |
| Encryption | RSA-2048 via pointycastle | End-to-end message encryption |
| Local Database | SQLite via sqflite | Persistent chat storage |
| UI Animations | flutter_animate | Transitions and feedback animations |
| Typography | Google Fonts — Outfit | Consistent visual language |
| Unique Identifiers | uuid | Message and device ID generation |
| Storage | shared_preferences | User profile persistence |
| Time Formatting | intl | Human-readable timestamps |

---

## Project Structure
lib/
├── main.dart
├── models/
│   └── message.dart                 Data models for Message and Peer
├── services/
│   └── nearby_service.dart          Core P2P logic, encryption, relay, PIN
├── utils/
│   ├── rsa_helper.dart              RSA key generation, encryption, decryption
│   └── database_helper.dart         SQLite operations for message persistence
├── screens/
│   ├── onboarding_screen.dart       First-time user setup
│   ├── home_screen.dart             Peer discovery and recent conversations
│   └── chat_screen.dart             Messaging interface
└── widgets/
└── pin_dialog.dart              PIN verification dialog

---

## Architecture

Linko follows a Service-Screen separation pattern. Screens handle only UI
rendering and user interaction. All networking, encryption, and data logic
is handled exclusively by NearbyService and utility classes.
Screens (UI Layer)
|
v
NearbyService (Logic Layer)
|
|-- RSAHelper          (Encryption)
|-- DatabaseHelper     (Persistence)
|-- Nearby Connections (Transport)

### Data Flow — Sending a Message

User types a message and taps Send
NearbyService retrieves the recipient's RSA public key
Message content is encrypted using RSA-2048 OAEP
Encrypted payload is JSON-encoded and converted to bytes
Bytes are transmitted via Nearby Connections (Bluetooth or WiFi Direct)
Message is saved to SQLite with decrypted content
UI updates with the sent message bubble


### Data Flow — Receiving a Message

onPayloadReceived callback fires with raw bytes
Bytes are decoded to JSON
Message type is identified (direct message or relay envelope)
Encrypted content is decrypted using the device's RSA private key
Decrypted message is stored in SQLite
UI callback fires and the message bubble appears


---

## Encryption

Linko uses RSA-2048 with OAEP padding for all message encryption.

### Key Generation

Each device generates an RSA-2048 key pair on first launch. The key pair
is stored locally in shared_preferences and persists across sessions.
The private key never leaves the device.

### Key Exchange

When two devices connect, they exchange public keys via an encrypted
handshake before any messages are sent. This ensures that all subsequent
messages can only be decrypted by the intended recipient.

### Encryption Process
Sender:
plaintext -> RSA encrypt (recipient public key) -> ciphertext -> transmit
Recipient:
ciphertext -> RSA decrypt (own private key) -> plaintext -> display

### Security Properties

- No third party, including devices relaying messages, can decrypt message content
- Private keys are stored only on the originating device
- All transmitted data is ciphertext — unreadable if intercepted
- The Nearby Connections API applies an additional layer of transport encryption

---

## PIN Verification

PIN verification prevents unauthorized devices from initiating a chat session.

### Process

Device A requests a connection to Device B
Connection is established at the transport layer
Both devices display the same randomly generated 6-digit PIN
Users verbally confirm the PIN matches on both screens
Both users tap Confirm to proceed
If PINs do not match, either user taps Reject and the connection is dropped
Only after mutual confirmation does the chat interface open


This approach mirrors the pairing model used by Bluetooth headsets and
prevents a nearby stranger with Linko installed from silently connecting.

---

## Mesh Relay

Mesh relay extends the effective range of Linko beyond the direct Bluetooth
or WiFi Direct range of two devices.

### How It Works
Direct connection (devices in range):
Device A <--------> Device B
Relayed connection (Device B out of range):
Device A --> Device C --> Device B
(C relays without reading content)

### Design Principles

- Messages are relayed as encrypted ciphertext only
- Intermediate devices cannot decrypt relayed messages
- Each message carries a TTL (Time To Live) counter, starting at 5
- The TTL decrements at each hop; messages with TTL of 0 are discarded
- A visited list prevents messages from looping back through the same device
- A deduplicated message ID set prevents duplicate deliveries

---

## Chat Persistence

All messages are stored locally in an SQLite database using the sqflite package.

### Storage Details

- Database location: on-device only, within the app's private storage
- Messages are stored in decrypted form after receipt
- Chat history is accessible across app restarts and sessions
- Deleting the app removes all stored messages permanently
- No data is ever transmitted to an external server or cloud

### Schema
Table: messages
id          TEXT PRIMARY KEY
peerId      TEXT
peerName    TEXT
senderId    TEXT
senderName  TEXT
content     TEXT
timestamp   INTEGER
isMe        INTEGER
isRelayed   INTEGER
Table: peers
id          TEXT PRIMARY KEY
name        TEXT
emoji       TEXT
lastSeen    INTEGER

---

## Getting Started

### Prerequisites

- Flutter SDK 3.44 or higher
- Android SDK 36
- Android device running Android 5.0 (API 21) or higher
- Bluetooth and Location enabled on the device

### Installation

```bash
git clone https://github.com/YOUR_USERNAME/skylink.git
cd skylink
flutter pub get
flutter run
```

### First Use

1. Open Linko on your device
2. Enter a display name and select an avatar
3. Grant Bluetooth and Location permissions when prompted
4. The home screen will begin scanning for nearby devices automatically

---

## Build and Distribution

### Debug Build

```bash
flutter run
```

### Release APK

```bash
flutter build apk --release
```

Output location:
build/app/outputs/flutter-apk/app-release.apk

### Installing on Another Device

1. Transfer the APK file via WhatsApp, email, or USB
2. On the recipient device, open the APK file
3. If prompted, enable Install from Unknown Sources in device settings
4. Tap Install and open Linko

---

## Permissions

### Android

| Permission | Purpose |
|---|---|
| BLUETOOTH | Classic Bluetooth (Android 11 and below) |
| BLUETOOTH_SCAN | Scan for nearby Bluetooth devices (Android 12+) |
| BLUETOOTH_ADVERTISE | Broadcast device presence (Android 12+) |
| BLUETOOTH_CONNECT | Connect to discovered devices (Android 12+) |
| ACCESS_FINE_LOCATION | Required by Android for Bluetooth scanning |
| NEARBY_WIFI_DEVICES | WiFi Direct peer discovery (Android 13+) |
| CHANGE_WIFI_STATE | Enable WiFi Direct connections |
| VIBRATE | Haptic feedback on message receipt |

---

## Device Specifications

| Specification | Value |
|---|---|
| Minimum Android version | Android 5.0 (API 21) |
| Target Android version | Android 16 (API 36) |
| Maximum simultaneous peers | 8 devices |
| Effective range | Approximately 100 metres (open air) |
| Maximum relay hops | 5 |
| Encryption standard | RSA-2048 with OAEP padding |
| Storage type | On-device SQLite |
| Internet requirement | None |

---

## Known Limitations

- iOS support is not included in the current release
- Range is subject to physical obstructions and interference
- RSA-2048 encryption introduces a minor delay on first message exchange
  while keys are generated and exchanged
- Chat history is lost permanently if the application is uninstalled
- Devices must have Linko open and running to be discoverable

---

## Roadmap

- Group broadcast messaging
- Image and file sharing
- Message read receipts
- Sound and vibration notification settings
- iOS support via TestFlight
- Export chat history as a text file
- Dark and light theme toggle

---

## License

This project is licensed under the MIT License.
You are free to use, modify, and distribute this software for any purpose,
provided the original license notice is retained.
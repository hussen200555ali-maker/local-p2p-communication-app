# AGENTS.md - تواصل محلي (Local Social App)

## Project Overview
P2P local network social app (Flutter/Dart). No server, no internet required.
Communication over WiFi: UDP broadcast (port 8081) for discovery, TCP (port 8080) for messaging.

## Architecture
- **Framework:** Flutter 3.35+ / Dart 3.9+
- **State management:** Provider + setState
- **Persistence:** SharedPreferences (settings, contacts, groups, call history), SQLite/sqflite (messages)
- **Encryption:** AES-256-CBC
- **Calls:** WebRTC via flutter_webrtc
- **Icons:** Iconsax pack
- **Font:** Cairo (Arabic-optimized)
- **Direction:** RTL (Arabic)

## Directory Structure
```
lib/
├── main.dart                    # Entry point + ThemeData
├── core/services/               # Backend services
│   ├── local_network_service.dart   # Core P2P networking (singleton)
│   ├── database_service.dart        # SQLite (singleton)
│   ├── encryption_service.dart      # AES-256-CBC (singleton)
│   └── system_notification_service.dart  # Notifications (singleton)
├── features/
│   ├── auth/          (models/, screens/)
│   ├── chat/          (models/, screens/)
│   ├── call/          (models/, screens/, services/, widgets/)
│   ├── notifications/ (models/, screens/)
│   ├── profile/       (screens/)
│   ├── settings/      (screens/)
│   └── status/        (models/)
└── shared/widgets/    # Empty - widgets are duplicated across screens
```

## Critical Conventions

### Code Style
- **NO comments** unless absolutely necessary for complex logic
- **NO emojis** in code or commit messages
- Arabic UI strings, English variable/function names
- Follow existing patterns (e.g. singleton, callback registration)

### Known Issues (Do NOT reintroduce)
1. **C-3**: All messages lost on restart - `_saveAllMessages()` writes but `_loadDataFromStorage()` never reads. Fix: ensure `_allMessages` is loaded from SharedPreferences on startup.
2. **C-4**: `acceptCall()` doesn't complete WebRTC handshake - missing `setRemoteDescription`.
3. **C-1/C-2**: Dark mode + privacy settings saved to SharedPreferences but never consumed by the app.
4. **C-5**: `toggleSpeaker()` calls non-existent method on `MediaStreamTrack`.
5. **C-6**: `cancelActiveCallNotification()` doesn't actually cancel the system notification.
6. **H-4**: `_groupCallsByDate` uses `DateTime.now()` instead of actual call date.

### Networking Protocol
- UDP discovery: port 8081, broadcast `255.255.255.255`
- TCP messaging: port 8080, `\n`-delimited JSON commands
- Command prefixes: `DISCOVER:`, `CONNECT_REQUEST:`, `MSG:`, `PING`, `GROUP_MSG:`, `FILE_START:`, `CALL_SIGNAL:`, `STATUS:`
- Singleton pattern: `LocalNetworkService()` factory returns same instance everywhere

### Settings Keys (SharedPreferences)
| Key | Type | Purpose |
|-----|------|---------|
| `dark_mode` | bool | Dark mode toggle |
| `show_online_status` | bool | Privacy: show online status |
| `read_receipts` | bool | Privacy: show read receipts |
| `username` | string | Current user's display name |
| `user_uuid` | string | Current user's UUID |
| `user_bio` | string | User biography |
| `user_avatar` | string | Avatar file path |
| `friend_ids_v3` | List<String> | Friend IDs |
| `call_history_v1` | JSON string | Call history |

### Callback Registration
Services use singleton pattern with callback registration:
```dart
_networkService.registerCallbacks(
  onFriendsChanged: () => setState(() {}),
  onPrivateMessageReceived: (msg) => ...,
  // etc.
);
_networkService.unregisterCallbacks(); // MUST call in dispose()
```

### Current State (v7.0)
- ✅ Private 1-on-1 chat with text/images/files
- ✅ Group chat
- ✅ Audio/Video calls (WebRTC - partially broken)
- ✅ Friend discovery via UDP broadcast
- ✅ Profile management
- ✅ Call history with filtering
- ✅ Notifications (local)
- ⚠️ Dark mode (toggle exists but non-functional)
- ⚠️ Privacy settings (saved but not applied)
- ❌ Message persistence on restart (critical)
- ❌ WebRTC handshake incomplete (critical)

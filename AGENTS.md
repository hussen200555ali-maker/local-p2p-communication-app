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
│   ├── system_notification_service.dart  # Notifications (singleton)
│   └── message_queue_service.dart   # Message queue (singleton)
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

### Documentation Discipline (Adopted 22 June 2026)
- **No execution before documentation**: Create/update status files BEFORE writing any code
- **No phase before approval**: Each phase must be documented and approved before starting
- **Update STATUS.md after every sub-phase completion**
- **Send a report before moving to the next sub-phase**
- **After every change:** `flutter build apk --debug` must remain clean

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
);
_networkService.unregisterCallbacks(); // MUST call in dispose()
```

### Lessons Learned (Previous Waves)

#### TCP Socket Stability
1. **PING/PONG to TCP** (not just UDP): TCP connections silently die. A dedicated PING command over TCP every 20s keeps the socket alive. Don't rely on UDP alone.
2. **Exponential Backoff Reconnect**: When a TCP socket drops, wait 1s, 2s, 4s, 8s... max 30s before retrying. Immediate retry floods the network.
3. **Zombie Socket Prevention**: Always check `!socket.done.isCompleted` before `socket.write()`. A closed socket that hasn't been nulled out will crash on write.
4. **Socket Removal**: `_removeSocket()` must null out the socket AFTER closing it. The order matters: close → remove from map → null.

#### SharedPreferences / Persistence
5. **Try-catch every JSON section**: In `_loadDataFromStorage()`, each of the 10 JSON sections must be wrapped in try-catch. One corrupt section must not block all others.
6. **SQLite as fallback**: After loading SharedPreferences, reconcile with SQLite via `DatabaseService.getAllMessages()` to catch messages that were saved to DB but not yet to SP.

#### Platform Guards
7. **`Platform.isWindows` before platform-specific calls**: `network_info_plus`, `permission_handler`, `flutter_local_notifications`, `sqflite`, `MethodChannel` all fail on Windows. Guard every call with `if (!Platform.isWindows)`.
8. **`path.basename()` over `split('/')`**: Windows uses `\` path separators. Always use `package:path` (`path.basename()`, `path.join()`) for file path manipulation.
9. **`dart:io` `NetworkInterface.list()` for Windows IP**: `network_info_plus.getWifiIP()` is mobile-only. On Windows, use `NetworkInterface.list()` and filter for 192.168.x.x or 10.x.x.x.

#### WebRTC Calls
10. **Null peerConnection after cleanup**: `_cleanupCall()` must set `_peerConnection = null` and `_localStream = null` after closing/disposing, otherwise `_createPeerConnection()` sees non-null and returns early.
11. **Drain pending signals**: Before completing `acceptCall()`, drain `_pendingSignals` list. The offer may have arrived before the peer connection was created.
12. **Guard against double-accept**: `_isAcceptingCall` boolean prevents `acceptCall()` from being called twice in parallel.

### Known Issues (Do NOT reintroduce)
1. **C-3**: All messages lost on restart - `_saveAllMessages()` writes but `_loadDataFromStorage()` never reads. Fix: ensure `_allMessages` is loaded from SharedPreferences on startup, with SQLite reconciliation fallback.
2. **C-4**: `acceptCall()` doesn't complete WebRTC handshake - missing `setRemoteDescription`. Fix: `_processSignal()` handles offer/answer correctly.
3. **C-1/C-2**: Dark mode + privacy settings saved to SharedPreferences but never consumed by the app. Fix: `darkModeNotifier` + public getters.
4. **C-5**: `toggleSpeaker()` calls non-existent method on `MediaStreamTrack`. Fix: use `Helper.setSpeakerphoneOn()`.
5. **C-6**: `cancelActiveCallNotification()` doesn't actually cancel the system notification. Fix: verify `_plugin.cancel(id)` is called.
6. **H-4**: `_groupCallsByDate` uses `DateTime.now()` instead of actual call date. Fix: use `Map<String, DateTime> groupDates` sorted by `DateTime.compareTo`.

### Current State (v7.0 — Post-Roadmap Adoption 22 June 2026)
- ✅ Private 1-on-1 chat with text/images/files
- ✅ Group chat
- ✅ Audio/Video calls (WebRTC - needs stabilization)
- ✅ Friend discovery via UDP broadcast
- ✅ Profile management
- ✅ Call history with filtering
- ✅ Notifications (local)
- ✅ Dark mode (functional via ValueNotifier)
- ✅ Privacy settings (functional via public getters)
- ✅ Message persistence on restart (SQLite fallback)
- ✅ WebRTC handshake (functional)
- ✅ Phase 1 (Windows port) + Installer complete
- 🟡 Phase 2 (iOS port) pending

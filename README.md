# LinguaFlow

LinguaFlow is a real-time multilingual chat application built with Flutter. It supports room-based messaging, live socket updates, authentication, translation-friendly messaging, and per-room unread tracking so users can quickly see what changed since their last visit.

## Features

- Real-time chat with Socket.IO updates
- Email/password authentication
- Create and join chat rooms with room codes
- Room member lists and presence indicators
- Multilingual messaging with supported language selection
- Message history with pagination and cached loading
- Per-room unread message checkpoints based on visit timestamps
- Light and dark themes using Material 3

## Tech Stack

- Flutter 3+
- BLoC for state management
- Dio for REST API calls
- Socket.IO client for realtime events
- Hive and SharedPreferences for local persistence
- `flutter_dotenv` for runtime configuration
- `intl` and `google_fonts` for formatting and UI polish

## Prerequisites

- Flutter SDK installed and available on your PATH
- A running LinguaFlow backend API and Socket.IO server
- A `.env` file in the project root with your API base URL

Example `.env`:

```env
API_BASE_URL=http://localhost:3000
```

If `API_BASE_URL` is not provided, the app falls back to the default value defined in `lib/core/config/api_config.dart`.

## Setup

1. Install dependencies:

```bash
flutter pub get
```

2. Create or update `.env` in the project root.

3. Make sure your backend exposes the authentication, rooms, and messages endpoints expected by the app.

## Run

Start the app on a connected device or emulator:

```bash
flutter run
```

If you want to run on a specific device, list devices first:

```bash
flutter devices
```

## Project Structure

- `lib/main.dart` initializes environment loading, local storage, and device orientation
- `lib/app.dart` wires repositories, blocs, routing, and theming
- `lib/core/` contains configuration, network, storage, and shared constants
- `lib/features/auth/` contains login and registration flows
- `lib/features/rooms/` contains the room list, create-room, and join-room flows
- `lib/features/chat/` contains message loading, sending, room membership, and unread checkpoint logic
- `lib/shared/` contains reusable UI widgets

## Backend Contract

The app expects a backend that provides these main capabilities:

- `POST /api/auth/login`
- `POST /api/auth/register`
- `GET /api/rooms`
- `POST /api/rooms`
- `POST /api/rooms/join`
- `GET /api/rooms/{roomId}/messages`
- `GET /api/rooms/{roomId}/messages/count`
- Socket events for live message delivery and typing indicators

The unread badge behavior relies on message timestamps and checkpoint timestamps. When a user leaves a room, the app stores a checkpoint and later asks the backend for messages created after that time.

## Notes

- The app is optimized for portrait mode on mobile devices.
- Local checkpoints are stored per room, so unread counts are tracked independently for each conversation.
- If the backend is unavailable, message counting gracefully falls back to `0`.

## Testing

Run the Flutter test suite with:

```bash
flutter test
```

## License

Add a license here if you plan to publish the project publicly.

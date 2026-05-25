# Quick Integration Guide - ChatScreen Updates

This file shows exactly how to integrate checkpoint tracking into your existing ChatScreen.

## Changes Needed in ChatScreen

### 1. Add Checkpoint Loading in `initState()`

Find this section:
```dart
@override
void initState() {
  super.initState();
  _chatBloc = context.read<ChatBloc>();
  _chatBloc.add(JoinRoom(widget.room.id));
  _chatBloc.add(LoadMessages(widget.room.id));
  // ... rest of code
}
```

Add these lines:
```dart
@override
void initState() {
  super.initState();
  _chatBloc = context.read<ChatBloc>();
  
  // Existing code
  _chatBloc.add(JoinRoom(widget.room.id));
  _chatBloc.add(LoadMessages(widget.room.id));
  
  // NEW: Load checkpoint to track message updates
  _chatBloc.add(LoadCheckpoint(widget.room.id));
  
  // NEW: Save entry time
  CheckpointService.saveLastVisited(widget.room.id, DateTime.now());
  
  // Rest of code...
  context.read<RoomsBloc>().add(rooms_events.MarkRoomAsRead(widget.room.id));
  _scrollController.addListener(_onScroll);
  // ...
}
```

### 2. Add Import at Top

```dart
import '../../../core/services/checkpoint_service.dart';
```

### 3. Add Checkpoint Saving in `dispose()`

Find this section:
```dart
@override
void dispose() {
  _scrollController.dispose();
  _messageController.dispose();
  _focusNode.dispose();
  super.dispose();
}
```

Update to:
```dart
@override
void dispose() {
  // NEW: Save checkpoint when leaving room
  _chatBloc.add(SaveCheckpoint(
    roomId: widget.room.id,
    timestamp: DateTime.now(),
  ));
  
  _scrollController.dispose();
  _messageController.dispose();
  _focusNode.dispose();
  super.dispose();
}
```

### 4. Optional: Display Checkpoint Info

Add this widget to your UI to show checkpoint information:

```dart
Widget _buildCheckpointInfo() {
  return BlocSelector<ChatBloc, ChatState, (DateTime?, int)>(
    selector: (state) => (state.checkpointTime, state.newMessageCount),
    builder: (context, data) {
      final (checkpointTime, newCount) = data;
      
      if (checkpointTime == null) {
        return const SizedBox.shrink();
      }
      
      final secondsElapsed = DateTime.now()
          .difference(checkpointTime)
          .inSeconds;
      
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (newCount > 0)
              Chip(
                label: Text('$newCount new messages'),
                backgroundColor: Colors.blue,
                labelStyle: const TextStyle(color: Colors.white),
              ),
            Text(
              'Last visited: ${secondsElapsed}s ago',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    },
  );
}
```

Then add it to your build() method:
```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: Text(widget.room.name)),
    body: Column(
      children: [
        _buildCheckpointInfo(),  // Add this
        Expanded(
          child: _buildMessageList(),
        ),
      ],
    ),
  );
}
```

### 5. Optional: Check Messages on Demand

Add a button to manually check for new messages:

```dart
ElevatedButton.icon(
  icon: const Icon(Icons.refresh),
  label: const Text('Check New Messages'),
  onPressed: () {
    _chatBloc.add(CheckMessagesSinceCheckpoint(widget.room.id));
  },
)
```

---

## Complete Integration Example

Here's a minimal working example:

```dart
import '../../../core/services/checkpoint_service.dart';

class _ChatScreenState extends State<ChatScreen> {
  late final ChatBloc _chatBloc;
  
  @override
  void initState() {
    super.initState();
    _chatBloc = context.read<ChatBloc>();
    
    // Load messages and checkpoint
    _chatBloc.add(JoinRoom(widget.room.id));
    _chatBloc.add(LoadMessages(widget.room.id));
    _chatBloc.add(LoadCheckpoint(widget.room.id));
    
    // Track entry time
    CheckpointService.saveLastVisited(widget.room.id, DateTime.now());
  }
  
  @override
  void dispose() {
    // Save checkpoint on exit
    _chatBloc.add(SaveCheckpoint(
      roomId: widget.room.id,
      timestamp: DateTime.now(),
    ));
    
    super.dispose();
  }
}
```

---

## Next Steps

1. ✅ Add imports and initialization code
2. ✅ Add checkpoint saving to dispose()
3. ✅ Test locally
4. ⏳ Implement backend endpoints (see CHECKPOINT_SYSTEM.md)
5. ⏳ Add UI to display new message count
6. ✅ Deploy to production

---

## Troubleshooting

### Checkpoint not saving
- Check that CheckpointService import is correct
- Verify SaveCheckpoint event is being added
- Check SharedPreferences setup in main.dart

### New message count always 0
- Verify backend endpoint returns messages correctly
- Check that `since` parameter is being sent
- Test backend manually: `GET /api/rooms/{id}/messages?since=2024-05-01T10:00:00.000Z`

### Multiple rooms interfering
- Each checkpoint is stored per roomId
- Verify widget.room.id is unique
- Check checkpoint prefix in CheckpointService

---

## Testing Locally

Without backend, test with mock data:

```dart
// Test checkpoint saving
await CheckpointService.saveCheckpoint(
  'test-room',
  DateTime.parse('2024-05-01T10:00:00.000Z'),
);

// Verify it was saved
final loaded = await CheckpointService.getCheckpoint('test-room');
print('Saved: $loaded');  // Should print the timestamp

// Test time calculation
final elapsed = await CheckpointService.getSecondsSinceCheckpoint('test-room');
print('Seconds elapsed: $elapsed');
```

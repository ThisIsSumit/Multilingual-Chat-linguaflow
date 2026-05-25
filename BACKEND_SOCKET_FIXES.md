# Backend Socket Implementation Guide - Message Delivery Status

## Problem
Message delivery status only updates when re-entering the chat screen. Real-time status updates are not working because the backend is not emitting socket events for message status changes.

## Frontend Changes (Already Implemented ✓)
The frontend has been updated to:
1. Listen for `message_sent_ack` socket events
2. Immediately update message status to "delivered" when ack is received
3. Removed unnecessary polling (reduced from 2s to 10s, only when not typing)
4. Added proper subscription cleanup

## Required Backend Changes

### 1. Message Sent Acknowledgment Flow
When a client sends a message via socket `send_message` event:

```javascript
// Server-side socket listener
socket.on('send_message', async (data) => {
  try {
    const { roomId, text } = data;
    const userId = socket.data.userId;  // from authentication
    
    // 1. Create message in DB
    const message = await Message.create({
      roomId,
      senderId: userId,
      originalText: text,
      status: 'delivered',  // Save as delivered immediately
      createdAt: new Date(),
      // ... other fields
    });
    
    // 2. Emit 'new_message' to all users in the room
    io.to(roomId).emit('new_message', {
      id: message.id,
      roomId: message.roomId,
      senderId: message.senderId,
      senderUsername: message.senderUsername,
      originalText: message.originalText,
      status: 'delivered',
      createdAt: message.createdAt,
      // ... all other message fields
    });
    
    // 3. IMPORTANT: Emit 'message_sent_ack' ONLY to the sender
    // This confirms the message was created and is delivered
    socket.emit('message_sent_ack', {
      messageId: message.id,
      status: 'delivered',
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    console.error('Error sending message:', error);
    socket.emit('error', { message: 'Failed to send message' });
  }
});
```

### 2. Message Read Status Update Flow
When other users see/read the message:

```javascript
// When user loads messages or marks room as read
socket.on('mark_read', async (data) => {
  try {
    const { roomId } = data;
    const userId = socket.data.userId;
    
    // Update all messages in the room for this user
    // Find the original sender of each message
    const messages = await Message.find({ roomId });
    
    for (const message of messages) {
      if (message.senderId !== userId && message.status !== 'read') {
        // Update message status to 'read'
        message.status = 'read';
        await message.save();
        
        // Emit status update to the SENDER of the message
        // Get the socket ID of the message sender (if they're online)
        const senderSocket = getUserSocket(message.senderId);
        if (senderSocket) {
          senderSocket.emit('message_status', {
            messageId: message.id,
            status: 'read'
          });
        }
      }
    }
  } catch (error) {
    console.error('Error marking messages as read:', error);
  }
});
```

### 3. Message Status Event Structure
The `message_status` event should follow this structure:

```javascript
// Event emitted to sender
{
  messageId: "msg_12345",
  status: "delivered" | "read",
  timestamp: "2026-05-01T12:30:00.000Z",
  roomId: "room_123"  // Optional but helpful
}
```

## Socket Event Flow Diagram

```
Client: User A sends message
│
├─→ socket.emit('send_message', { roomId, text })
│
Server receives:
│
├─→ Create message in DB
├─→ io.to(roomId).emit('new_message', {...}) 
│   └─→ All users in room get the message
├─→ socket.emit('message_sent_ack', { messageId, status: 'delivered' })
│   └─→ ONLY sender (User A) gets this confirmation
│
Client (User A) receives:
│
└─→ socket.on('message_sent_ack', ...) 
    └─→ Update message UI to show ✓✓ (delivered)

---

Client: User B reads room / receives message
│
├─→ Marked as read
│
Server:
│
├─→ Update message status to 'read'
├─→ Find message sender's socket
├─→ socket.emit('message_status', { messageId, status: 'read' })
│
Client (User A) receives:
│
└─→ socket.on('message_status', ...)
    └─→ Update message UI to show ✓✓ in blue (read)
```

## Database Schema Requirements

The `Message` table should have:

```javascript
{
  id: String (UUID),
  roomId: String,
  senderId: String,
  senderUsername: String,
  originalText: String,
  translations: Map<String, String>,  // e.g., { "Spanish": "...", "French": "..." }
  detectedLanguage: String,
  status: String,  // 'sent' | 'delivered' | 'read'
  createdAt: DateTime,
  updatedAt: DateTime
}
```

## Implementation Checklist

- [ ] Add `message_sent_ack` event emission when message is created
- [ ] Add `message_status` event emission when message is marked as read
- [ ] Ensure `message_sent_ack` is ONLY emitted to the sender
- [ ] Ensure `message_status` updates are emitted to the sender only
- [ ] Handle offline scenarios (store status updates for when user comes back online)
- [ ] Add proper error handling and logging
- [ ] Test with multiple users to ensure status updates work correctly
- [ ] Add timestamp to all status events for debugging

## Testing Steps

1. **Test Delivery Status:**
   - User A sends message
   - Check that UI immediately shows ✓ (sent) then ✓✓ (delivered) 
   - No need to refresh

2. **Test Read Status:**
   - User B receives the message
   - Check that User A sees ✓✓ turn blue (read status)
   - Works in real-time

3. **Test Edge Cases:**
   - Offline user sends message when connection restored
   - Multiple users in same room
   - Rapid message sending

## Debugging Tips

Add console logs in socket handlers:
```javascript
console.log(`[SOCKET] New message from ${userId} in room ${roomId}: ${text}`);
console.log(`[SOCKET] Emitting message_sent_ack for message ${messageId}`);
console.log(`[SOCKET] Emitting message_status update: ${messageId} -> ${status}`);
```

Enable socket debugging in Flutter:
```dart
debugPrint('[SOCKET] Event received: $eventName');
```

The frontend will now show delivery status in real-time when these events are properly emitted from the backend!

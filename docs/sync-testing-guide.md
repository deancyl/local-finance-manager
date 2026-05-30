# Multi-Device Sync Testing Guide

## Overview

This guide covers end-to-end testing of the multi-device sync system in Local Finance Manager. All sync features are now complete:

- **v0.3.203**: WebSocket real-time sync notifications
- **v0.3.204**: QR code device pairing
- **v0.3.204**: Offline queue with retry mechanism
- **v0.3.205**: Sync status indicator in app bar

## Prerequisites

### Hardware Requirements

- Two mobile devices (Android/iOS) OR
- One mobile device + one desktop (Windows/macOS/Linux) OR
- Two desktop instances

### Software Requirements

- Sync server deployed (see [Sync Server Deployment](./sync-server-deployment.md))
- Local Finance Manager app installed on all test devices
- Network connectivity between devices and sync server

---

## Testing Checklist

### Phase 1: Server Setup

- [ ] Sync server deployed and running
- [ ] PostgreSQL database initialized
- [ ] WebSocket endpoint accessible
- [ ] Health check returns 200 OK
- [ ] Firewall allows ports 3000 (API) and 8080 (PowerSync)

### Phase 2: Device Registration

- [ ] Device A registers successfully
- [ ] Device B registers successfully
- [ ] Both devices appear in device list
- [ ] Device names are editable

### Phase 3: QR Pairing

- [ ] Device A generates QR code
- [ ] Device B scans QR code
- [ ] Pairing completes successfully
- [ ] Paired device appears in device list
- [ ] Both devices show "connected" status

### Phase 4: Data Sync

- [ ] Create transaction on Device A
- [ ] Transaction syncs to Device B
- [ ] Edit transaction on Device B
- [ ] Edit syncs to Device A
- [ ] Delete transaction on Device A
- [ ] Delete syncs to Device B

### Phase 5: WebSocket Notifications

- [ ] WebSocket connects on both devices
- [ ] Sync indicator shows green (connected)
- [ ] Change on Device A triggers immediate sync
- [ ] Device B receives change within 2 seconds
- [ ] Sync indicator shows sync activity

### Phase 6: Offline Queue

- [ ] Disable network on Device A
- [ ] Create transaction offline
- [ ] Transaction appears in offline queue
- [ ] Sync indicator shows pending count
- [ ] Re-enable network
- [ ] Offline transaction syncs automatically
- [ ] Queue clears after successful sync

### Phase 7: Conflict Resolution

- [ ] Edit same transaction on both devices simultaneously
- [ ] Conflict detected and logged
- [ ] Resolution rule applied correctly:
  - [ ] Delete wins over update
  - [ ] Newer timestamp wins for non-critical fields
  - [ ] Amount changes require manual review
  - [ ] Reconciled transactions require manual review

---

## Detailed Testing Procedures

### 1. Sync Server Deployment Test

#### Steps

1. Navigate to sync server directory:
   ```bash
   cd apps/sync-server
   ```

2. Start the server:
   ```bash
   # Using Docker (recommended)
   docker-compose up -d
   
   # Or run directly
   dart run server.dart
   ```

3. Verify health check:
   ```bash
   curl http://localhost:3000/health
   # Expected: {"status":"ok"}
   ```

4. Check WebSocket endpoint:
   ```bash
   curl -i -N -H "Connection: Upgrade" -H "Upgrade: websocket" \
        -H "Sec-WebSocket-Key: test" -H "Sec-WebSocket-Version: 13" \
        http://localhost:3000/ws
   # Expected: 101 Switching Protocols
   ```

#### Expected Results

- Server starts without errors
- Health check returns 200 OK
- WebSocket upgrade returns 101

#### Troubleshooting

| Issue | Solution |
|-------|----------|
| Port already in use | Check for existing processes: `lsof -i :3000` |
| Database connection failed | Verify PostgreSQL is running and credentials are correct |
| WebSocket upgrade fails | Check middleware configuration in `routes/_middleware.dart` |

---

### 2. Device Registration Test

#### Steps

1. **Device A Setup**:
   - Open app → Settings → Sync Settings
   - Enable sync feature toggle
   - Enter server URL: `http://<server-ip>:3000`
   - Tap "Register"
   - Enter email and password
   - Verify registration success message

2. **Device B Setup**:
   - Repeat steps from Device A
   - Use same account credentials (email/password)

3. **Verify Device List**:
   - On either device, go to Settings → Sync Settings → Manage Devices
   - Verify both devices appear in list
   - Check device names are editable

#### Expected Results

- Both devices register successfully
- JWT tokens stored in secure storage
- Device IDs generated and stored
- Both devices appear in device list

#### Troubleshooting

| Issue | Solution |
|-------|----------|
| Registration fails | Check server logs for errors |
| "Server unreachable" | Verify network connectivity and server URL |
| "Invalid credentials" | Check email format and password requirements |
| Devices not showing | Pull to refresh device list |

---

### 3. QR Code Pairing Test

#### Steps

1. **Generate QR on Device A**:
   - Go to Settings → Sync Settings → Pair Device
   - Verify QR code displays
   - Note the device name shown
   - Check QR expiration time (5 minutes)

2. **Scan QR on Device B**:
   - Go to Settings → Sync Settings → Pair Device
   - Tap "Scan QR Code" button
   - Grant camera permission if prompted
   - Scan the QR code from Device A

3. **Verify Pairing**:
   - Both devices show "Pairing successful" message
   - Paired device appears in device list
   - Sync status indicator shows connected

#### Expected Results

- QR code generates with valid token
- QR contains: server URL, pairing token, device ID
- Scanning completes pairing within 3 seconds
- Both devices can sync with each other

#### Troubleshooting

| Issue | Solution |
|-------|----------|
| QR not generating | Check WebSocket connection status |
| Camera permission denied | Grant permission in device settings |
| "Invalid QR code" | Ensure scanning the correct QR (same account) |
| Pairing timeout | Regenerate QR and try again |

---

### 4. Data Synchronization Test

#### Test 4.1: Create Transaction

1. **On Device A**:
   - Create new transaction: Amount ¥100, Category "餐饮"
   - Save transaction
   - Note the transaction ID

2. **On Device B**:
   - Wait 2-5 seconds (or pull to refresh)
   - Verify transaction appears with same amount and category

#### Test 4.2: Edit Transaction

1. **On Device B**:
   - Open the synced transaction
   - Change amount to ¥150
   - Save changes

2. **On Device A**:
   - Wait 2-5 seconds
   - Verify amount updated to ¥150

#### Test 4.3: Delete Transaction

1. **On Device A**:
   - Delete the test transaction

2. **On Device B**:
   - Wait 2-5 seconds
   - Verify transaction removed from list

#### Expected Results

- All CRUD operations sync within 5 seconds
- Data integrity maintained (no data loss)
- Sync indicator shows activity during sync

---

### 5. WebSocket Notification Test

#### Steps

1. **Verify WebSocket Connection**:
   - Check sync status indicator in app bar
   - Tap indicator to open status sheet
   - Verify "WebSocket: Connected" shown

2. **Test Real-Time Sync**:
   - Keep both devices on sync settings page
   - Create transaction on Device A
   - Observe Device B: Transaction should appear within 2 seconds
   - No manual refresh needed

3. **Test Sync Indicator**:
   - During sync, indicator should show:
     - Blue spinner: Syncing in progress
     - Green checkmark: Synced successfully
     - Badge count: Pending operations

#### Expected Results

- WebSocket maintains persistent connection
- Changes trigger immediate sync notification
- Sync indicator reflects current state accurately
- No polling delay (instant sync)

#### Troubleshooting

| Issue | Solution |
|-------|----------|
| WebSocket disconnects | Check network stability, server logs |
| "Real-time sync: Not connected" | Verify WebSocket endpoint is accessible |
| Delayed sync | Check WebSocket reconnection logic |

---

### 6. Offline Queue Test

#### Steps

1. **Simulate Offline**:
   - Enable airplane mode on Device A
   - OR disable WiFi/mobile data

2. **Create Offline Data**:
   - Create 3 transactions while offline
   - Verify each shows "pending" indicator

3. **Check Offline Queue**:
   - Go to Settings → Sync Settings → Offline Queue
   - Verify 3 items in queue
   - Check status: "Pending"

4. **Reconnect**:
   - Disable airplane mode
   - Wait for auto-sync (within 30 seconds)
   - OR tap "Sync Now" button

5. **Verify Sync**:
   - Check offline queue: Should be empty
   - Check Device B: All 3 transactions synced

#### Test Retry Logic

1. Create transaction offline
2. Reconnect with server down
3. Verify: Transaction moves to "Failed" state
4. Bring server up
5. Tap "Retry" on failed item
6. Verify: Transaction syncs successfully

#### Expected Results

- Offline operations queued locally
- Queue persists across app restarts
- Auto-sync on reconnection
- Retry mechanism works for failed items
- Queue badge shows accurate count

---

### 7. Conflict Resolution Test

#### Test 7.1: Last-Write-Wins (Timestamp)

1. Create transaction on Device A
2. Wait for sync to Device B
3. Edit on Device B: Change notes to "Edit from B"
4. Immediately edit on Device A: Change notes to "Edit from A"
5. Sync both devices
6. Verify: Later edit wins based on timestamp

#### Test 7.2: Amount Change (Manual Review)

1. Create transaction: Amount ¥100
2. Sync both devices
3. On Device A: Change amount to ¥200
4. On Device B: Change amount to ¥300
5. Sync both devices
6. Verify: Conflict logged, requires manual resolution
7. Go to Settings → Sync Settings → Conflicts
8. Choose resolution: Keep ¥200 or ¥300

#### Test 7.3: Delete Wins

1. Create transaction on Device A
2. Sync to Device B
3. On Device A: Edit transaction (change notes)
4. On Device B: Delete transaction
5. Sync both devices
6. Verify: Transaction deleted on both devices

#### Test 7.4: Reconciled Transaction

1. Create and reconcile a transaction
2. Sync to Device B
3. Edit on both devices simultaneously
4. Verify: Conflict requires manual review (reconciled protection)

#### Expected Results

- Conflicts detected and logged
- Resolution rules applied correctly
- Manual conflicts show in conflict list
- User can choose resolution
- No data corruption

---

## Sync Status Indicator Reference

The sync status indicator in the app bar shows:

| Icon | Color | Meaning |
|------|-------|---------|
| ✓ Cloud | Green | Connected and synced |
| ⟳ Cloud | Blue | Syncing in progress |
| ⚠ Cloud | Yellow | Reconnecting |
| ✗ Cloud | Red | Error |
| ⊘ Cloud | Gray | Offline/Not configured |
| ⟳ Spinner | Blue | Active sync operation |

**Badge Indicators**:
- Number badge: Pending operations count
- Red badge: Failed operations present
- Blue badge: Pending operations only

---

## Troubleshooting Guide

### Common Issues

#### 1. Sync Not Working

**Symptoms**:
- Data not syncing between devices
- Sync indicator shows "disconnected"

**Diagnosis**:
```bash
# Check server health
curl http://<server-ip>:3000/health

# Check WebSocket
curl -i -N -H "Connection: Upgrade" -H "Upgrade: websocket" \
     -H "Sec-WebSocket-Key: test" -H "Sec-WebSocket-Version: 13" \
     http://<server-ip>:3000/ws

# Check server logs
docker logs sync-server-api-1
```

**Solutions**:
1. Verify server is running
2. Check network connectivity
3. Verify JWT token is valid (not expired)
4. Check device is registered

#### 2. WebSocket Disconnects Frequently

**Symptoms**:
- Sync indicator flickers between connected/disconnected
- "Real-time sync: Reconnecting..." message

**Solutions**:
1. Check network stability
2. Increase WebSocket heartbeat interval
3. Check server resource usage
4. Verify no firewall timeout

#### 3. Offline Queue Not Syncing

**Symptoms**:
- Queue items stuck in "pending" state
- Items not syncing after reconnection

**Solutions**:
1. Check sync service is running
2. Verify network is actually connected
3. Check for failed items (server errors)
4. Tap "Retry" on failed items
5. Check server logs for errors

#### 4. Conflicts Not Resolving

**Symptoms**:
- Conflicts stuck in "pending" state
- Manual resolution not saving

**Solutions**:
1. Check user has permission to resolve
2. Verify conflict data is valid
3. Check server conflict resolution endpoint
4. Review conflict resolution rules

#### 5. QR Pairing Fails

**Symptoms**:
- "Invalid QR code" error
- Pairing timeout

**Solutions**:
1. Ensure both devices use same account
2. Check QR hasn't expired (5 min timeout)
3. Verify camera permission granted
4. Check WebSocket connection for pairing

#### 6. Performance Issues

**Symptoms**:
- Slow sync (>10 seconds)
- App lag during sync

**Solutions**:
1. Check database size (large datasets)
2. Verify network bandwidth
3. Check server resource usage
4. Consider incremental sync settings

---

## Test Automation

### Integration Test Script

```dart
// test/integration/sync_test.dart

testWidgets('Multi-device sync flow', (tester) async {
  // 1. Setup two device simulators
  final deviceA = await setupDevice('device_a');
  final deviceB = await setupDevice('device_b');
  
  // 2. Register both devices
  await deviceA.register(email: 'test@example.com', password: 'password');
  await deviceB.register(email: 'test@example.com', password: 'password');
  
  // 3. Create transaction on A
  await deviceA.createTransaction(amount: 100, category: 'food');
  
  // 4. Wait for sync
  await Future.delayed(Duration(seconds: 5));
  
  // 5. Verify on B
  final transactions = await deviceB.getTransactions();
  expect(transactions.length, 1);
  expect(transactions.first.amount, 100);
});
```

### Manual Test Log Template

```
Date: YYYY-MM-DD
Tester: [Name]
Devices: Device A (Model/OS), Device B (Model/OS)
Server Version: vX.X.X

| Test Case | Status | Notes |
|-----------|--------|-------|
| Server deployment | ✅/❌ | |
| Device registration | ✅/❌ | |
| QR pairing | ✅/❌ | |
| Create sync | ✅/❌ | |
| Edit sync | ✅/❌ | |
| Delete sync | ✅/❌ | |
| WebSocket | ✅/❌ | |
| Offline queue | ✅/❌ | |
| Conflict resolution | ✅/❌ | |

Issues Found:
- [Description]

Recommendations:
- [Suggestion]
```

---

## Related Documentation

- [Sync Server Deployment](./sync-server-deployment.md)
- [Sync Architecture](./SYNC_ARCHITECTURE.md)
- [API Documentation](./API.md)
- [Security Guide](./SECURITY.md)

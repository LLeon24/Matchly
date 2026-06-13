# iCloud Sync Troubleshooting Guide

## Overview
Matchly uses `NSUbiquitousKeyValueStore` for iCloud synchronization. This provides automatic syncing across all your devices, but has some limitations and requirements.

## Common Issues and Solutions

### 1. iCloud Not Available
**Symptoms:**
- "iCloud not available" message in Settings
- Sync button is disabled

**Solutions:**
1. **Sign in to iCloud:**
   - Go to Settings → [Your Name] → iCloud
   - Make sure you're signed in with your Apple ID

2. **Enable iCloud Drive:**
   - Settings → [Your Name] → iCloud
   - Toggle "iCloud Drive" to ON

3. **Enable iCloud Key-Value Store in Xcode:**
   - Open the project in Xcode
   - Select the app target
   - Go to "Signing & Capabilities"
   - Click "+ Capability"
   - Add "iCloud"
   - Check "Key-value storage"
   - Make sure the container identifier is set (e.g., `iCloud.com.yourcompany.Matchly`)

4. **Restart the app** after enabling iCloud

### 2. Data Too Large
**Symptoms:**
- Error message: "Programs data is too large (X.XX MB). Maximum is 1 MB per key."
- Sync fails silently

**Why:**
- `NSUbiquitousKeyValueStore` has a **1MB limit per key**
- If you have many programs with detailed questionnaires, data can exceed this limit

**Solutions:**
1. **Use Export/Import instead:**
   - Settings → Backup & Sync → Export All Data
   - Transfer the JSON file to your other device
   - Import it on the other device

2. **Reduce data size:**
   - Remove programs you no longer need
   - Clear old questionnaire data
   - Remove unused custom sections

3. **Check data size:**
   - Settings → Backup & Sync → iCloud Status & Diagnostics
   - This will show the exact size of your data

### 3. Sync Not Working
**Symptoms:**
- "Last synced: Never" even after tapping "Sync Now"
- No error message but data doesn't appear on other devices

**Solutions:**
1. **Check diagnostics:**
   - Settings → Backup & Sync → iCloud Status & Diagnostics
   - This will show detailed status information

2. **Manual sync:**
   - Tap "Sync Now" button
   - Wait a few seconds
   - Check the "Last synced" time

3. **Check network connection:**
   - iCloud sync requires internet connection
   - Make sure Wi-Fi or cellular data is enabled

4. **Wait for automatic sync:**
   - iCloud sync happens automatically when:
     - You save programs or preferences
     - The app detects changes
   - It may take a few minutes to appear on other devices

5. **Restart both devices:**
   - Sometimes iCloud needs a refresh
   - Close the app completely and reopen it

### 4. Data Not Appearing on Other Device
**Symptoms:**
- Synced on one device but not showing on another

**Solutions:**
1. **Make sure both devices use the same Apple ID:**
   - Settings → [Your Name] on both devices
   - They must be signed in to the same iCloud account

2. **Wait for sync:**
   - iCloud sync is not instant
   - Can take a few minutes to hours depending on network

3. **Force sync on the receiving device:**
   - Open Matchly on the other device
   - Settings → Backup & Sync → Sync Now
   - This will pull the latest data from iCloud

4. **Check if data exists in cloud:**
   - Use "iCloud Status & Diagnostics" on the source device
   - It will show if data is in the cloud

### 5. Sync Errors
**Symptoms:**
- Red error message appears
- "Failed to synchronize with iCloud"

**Solutions:**
1. **Check the error message:**
   - It will tell you the specific issue
   - Common errors:
     - "iCloud not available" → Sign in to iCloud
     - "Data too large" → Use export/import instead
     - "Failed to encode" → Data corruption, try export/import

2. **Try again:**
   - Sometimes it's a temporary network issue
   - Tap "Sync Now" again

3. **Export as backup:**
   - Always have a local backup
   - Settings → Backup & Sync → Export All Data

## Technical Details

### How It Works
- Uses `NSUbiquitousKeyValueStore` (iCloud Key-Value Store)
- Automatically syncs when you save data
- Syncs across all devices signed in to the same Apple ID
- Maximum 1MB per key, 1MB total per app

### Limitations
- **1MB per key limit:** If your programs data exceeds 1MB, sync will fail
- **1MB total limit:** All keys combined cannot exceed 1MB
- **Not instant:** Sync can take minutes to hours
- **Requires internet:** No offline sync

### When to Use Export/Import Instead
- If you have more than ~100-200 programs with detailed questionnaires
- If sync keeps failing due to size
- For one-time transfers between devices
- As a backup solution

## Checking Sync Status

1. **In the app:**
   - Settings → Backup & Sync
   - Look at "iCloud Sync" section
   - Check "Last synced" time
   - Look for error messages

2. **Diagnostics:**
   - Settings → Backup & Sync → iCloud Status & Diagnostics
   - Shows detailed information about:
     - iCloud availability
     - Data in cloud
     - Data sizes
     - Last sync time

3. **Console logs:**
   - In Xcode, check the console
   - Look for messages starting with:
     - `✓ Successfully synced to iCloud`
     - `⚠️ iCloud sync failed`
     - `📊 iCloud sync data sizes`

## Best Practices

1. **Regular backups:**
   - Export your data periodically
   - Don't rely solely on iCloud

2. **Monitor data size:**
   - Check diagnostics if sync fails
   - Keep programs count reasonable

3. **Manual sync:**
   - Use "Sync Now" before switching devices
   - Wait for confirmation before closing app

4. **Network awareness:**
   - Sync requires internet
   - Use Wi-Fi for large syncs if possible

## Still Having Issues?

If iCloud sync still doesn't work after trying these solutions:

1. **Check Xcode project:**
   - Make sure iCloud capability is enabled
   - Container identifier is set correctly
   - App is signed with proper provisioning profile

2. **Check device:**
   - Settings → [Your Name] → iCloud
   - Make sure iCloud Drive is enabled
   - Check available iCloud storage

3. **Use Export/Import:**
   - This is a reliable alternative
   - Works regardless of iCloud status
   - Can transfer data between any devices

4. **Contact support:**
   - Include diagnostic information
   - Note the exact error messages
   - Describe what you've tried



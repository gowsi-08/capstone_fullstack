# Location Mode Toggle Feature

## Overview

Added a global location mode toggle in the admin dashboard that allows admins to switch between WiFi-based and GPS-based location prediction. This setting is stored in the database and automatically applies to all users when they use the map screen for navigation.

## What Was Implemented

### 1. Backend API Endpoints

**File:** `backend/routes/api.py`

**New Endpoints:**

#### GET `/admin/location_mode`
Get the current location prediction mode.

**Response:**
```json
{
  "mode": "wifi"  // or "gps"
}
```

#### POST `/admin/location_mode`
Set the location prediction mode.

**Request:**
```json
{
  "mode": "wifi"  // or "gps"
}
```

**Response:**
```json
{
  "success": true,
  "mode": "wifi"
}
```

**Storage:** Saved in MongoDB `app_settings` collection with key `location_mode`.

### 2. Updated Prediction Endpoint

**File:** `backend/routes/api.py`

**Endpoint:** `POST /getlocation`

Now supports both WiFi and GPS data:

**WiFi Mode (existing):**
```json
[
  {"BSSID": "aa:bb:cc:dd:ee:ff", "Signal Strength dBm": -45},
  {"BSSID": "11:22:33:44:55:66", "Signal Strength dBm": -67}
]
```

**GPS Mode (new):**
```json
[
  {"latitude": 12.934567, "longitude": 77.612345}
]
```

The endpoint automatically detects the data type and processes accordingly:
- WiFi data → ML model prediction
- GPS data → Nearest node calculation using Haversine distance

### 3. Frontend Admin Dashboard Toggle

**File:** `frontend/lib/admin_dashboard_screen.dart`

**Features:**
- Toggle in top bar (right side)
- Two buttons: "WiFi" (blue) and "GPS" (green)
- Active mode is highlighted
- Loads current mode on screen init
- Saves to database when toggled
- Shows confirmation snackbar

**UI Design:**
- WiFi button: Blue (#2979FF) when active
- GPS button: Green (#00C853) when active
- Inactive buttons: Gray/transparent
- Icons: WiFi icon and GPS icon
- Positioned in top bar for easy access

### 4. Frontend API Methods

**File:** `frontend/lib/api_service.dart`

**New Methods:**

#### `getLocationMode()`
Fetches the current location mode from server.

```dart
final mode = await ApiService.getLocationMode();
// Returns: 'wifi' or 'gps'
```

#### `setLocationMode(String mode)`
Sets the location mode on server.

```dart
final success = await ApiService.setLocationMode('gps');
// Returns: true if successful
```

### 5. Updated Map Screen

**File:** `frontend/lib/map_screen.dart`

**Changes:**

#### Modified `_locateUser()` function:
1. Checks location mode from server
2. Calls `_locateUserWiFi()` if mode is 'wifi'
3. Calls `_locateUserGPS()` if mode is 'gps'

#### New `_locateUserGPS()` function:
1. Checks GPS permissions
2. Gets current GPS coordinates
3. Sends to server as `{latitude, longitude}`
4. Server finds nearest node with GPS coordinates
5. Updates map with predicted location
6. Shows distance in meters

#### Existing `_locateUserWiFi()` function:
- Renamed from original `_locateUser()` logic
- Handles WiFi scanning and prediction
- No changes to WiFi logic

## How It Works

### Admin Workflow:

1. **Admin logs in** and goes to Admin Dashboard
2. **Sees toggle** in top bar (WiFi/GPS buttons)
3. **Clicks GPS button** to switch to GPS mode
4. **Setting is saved** to database
5. **All users** now use GPS mode automatically

### User Workflow (WiFi Mode):

1. User opens map screen
2. Clicks "Find My Location" button
3. App checks mode from server → "wifi"
4. App scans WiFi networks
5. Sends WiFi data to server
6. Server uses ML model to predict location
7. Map shows predicted location

### User Workflow (GPS Mode):

1. User opens map screen
2. Clicks "Find My Location" button
3. App checks mode from server → "gps"
4. App gets GPS coordinates
5. Sends GPS data to server
6. Server finds nearest node with GPS coordinates
7. Map shows nearest location with distance

## Technical Details

### Database Schema:

**Collection:** `app_settings`

**Document:**
```json
{
  "key": "location_mode",
  "value": "wifi"  // or "gps"
}
```

### GPS Distance Calculation:

Uses Haversine formula to calculate distance between two GPS coordinates:

```python
from math import radians, sin, cos, sqrt, atan2

R = 6371000  # Earth radius in meters

lat1 = radians(user_latitude)
lat2 = radians(node_latitude)
dlat = radians(node_latitude - user_latitude)
dlng = radians(node_longitude - user_longitude)

a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlng/2)**2
c = 2 * atan2(sqrt(a), sqrt(1-a))
distance = R * c  # Distance in meters
```

### Prediction Endpoint Logic:

```python
def get_prediction():
    data = request.get_json()
    
    # Check if GPS data
    is_gps = isinstance(data, dict) and 'latitude' in data
    
    if is_gps:
        # Find nearest node with GPS coordinates
        # Calculate Haversine distance
        # Return nearest node
    else:
        # WiFi mode (existing logic)
        # Use ML model to predict
        # Return predicted location
```

## Use Cases

### 1. Outdoor Navigation
- Admin sets mode to GPS
- Users navigate using GPS outdoors
- More accurate near building entrances
- Works without WiFi training data

### 2. Indoor Navigation
- Admin sets mode to WiFi
- Users navigate using WiFi indoors
- More accurate inside buildings
- Requires trained ML model

### 3. Hybrid Scenarios
- Admin can switch modes based on time/location
- GPS for outdoor events
- WiFi for indoor operations
- Easy toggle without app restart

### 4. Testing & Debugging
- Switch modes to compare accuracy
- Test GPS mapping effectiveness
- Verify WiFi model performance
- Troubleshoot location issues

## Advantages

### WiFi Mode:
- ✅ Excellent indoor accuracy (2-5 meters)
- ✅ Works in buildings without GPS signal
- ✅ Room-level precision
- ❌ Requires training data collection
- ❌ Requires model training
- ❌ Limited outdoors

### GPS Mode:
- ✅ Works outdoors (3-10 meters)
- ✅ No training data needed
- ✅ Works immediately after GPS mapping
- ✅ Good for entrances/exits
- ❌ Poor indoor accuracy
- ❌ Requires GPS coordinates on nodes
- ❌ Requires clear sky view

## Configuration

### Default Mode:
- **WiFi** (if no setting exists in database)

### Changing Mode:
1. Login as admin
2. Go to Admin Dashboard
3. Click WiFi or GPS button in top bar
4. Mode changes immediately
5. All users affected on next location request

### Permissions Required:

**WiFi Mode:**
- Location permission (for WiFi scanning)
- WiFi must be enabled

**GPS Mode:**
- Location permission (for GPS)
- GPS must be enabled
- Clear sky view (outdoors)

## Error Handling

### WiFi Mode Errors:
- No WiFi networks found → Show error
- Model not loaded → Show error
- Location not in training data → Show error
- WiFi disabled → Prompt to enable

### GPS Mode Errors:
- Location permission denied → Show error
- GPS not available → Show error
- No nodes with GPS coordinates → Show error
- GPS accuracy too low → Still works, shows distance

## Visual Indicators

### Admin Dashboard Toggle:
- **Active WiFi:** Blue button with white text
- **Active GPS:** Green button with white text
- **Inactive:** Gray/transparent with dim text
- **Icons:** WiFi and GPS icons for clarity

### Map Screen:
- No visual indicator (users don't see mode)
- Works transparently based on admin setting
- Same "Find My Location" button
- Same location display

## Testing

### Test WiFi Mode:
1. Set mode to WiFi in admin dashboard
2. Open map screen as user
3. Click "Find My Location"
4. Should scan WiFi and predict location
5. Check console logs for "WiFi location request"

### Test GPS Mode:
1. Set mode to GPS in admin dashboard
2. Open map screen as user
3. Click "Find My Location"
4. Should get GPS and find nearest node
5. Check console logs for "GPS location request"

### Test Toggle:
1. Login as admin
2. Go to admin dashboard
3. Click WiFi button → Should highlight blue
4. Click GPS button → Should highlight green
5. Refresh page → Should remember selection

## Files Modified/Created

### Backend:
- `backend/routes/api.py` - Added mode endpoints, updated prediction endpoint

### Frontend:
- `frontend/lib/admin_dashboard_screen.dart` - Added toggle in top bar
- `frontend/lib/api_service.dart` - Added getLocationMode() and setLocationMode()
- `frontend/lib/map_screen.dart` - Added GPS support, split location functions

### Documentation:
- `LOCATION_MODE_TOGGLE_FEATURE.md` - This file

## Future Enhancements

1. **Automatic Mode Switching**
   - Detect indoor/outdoor automatically
   - Switch modes based on GPS accuracy
   - Hybrid mode using both WiFi and GPS

2. **Per-Floor Mode**
   - Different modes for different floors
   - GPS for ground floor, WiFi for upper floors

3. **User Preferences**
   - Allow users to override admin setting
   - Personal mode preference

4. **Mode Analytics**
   - Track which mode is more accurate
   - Log mode usage statistics
   - Compare WiFi vs GPS accuracy

5. **Fallback Logic**
   - Try GPS first, fallback to WiFi if no GPS nodes
   - Try WiFi first, fallback to GPS if model fails

## Status

✅ **COMPLETE** - Feature fully implemented and ready to use!

---

**Version:** 1.0.0  
**Date:** March 29, 2026  
**Feature Type:** Admin Setting  
**Scope:** Global (affects all users)

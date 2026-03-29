# Geolocation Mapping Feature

## Overview

Added optional GPS coordinates (latitude/longitude) to graph nodes, allowing admins to map indoor nodes to real-world GPS coordinates.

## What Was Implemented

### 1. GraphNode Model Updates

**File:** `frontend/lib/models/graph_models.dart`

Added two optional fields to GraphNode:
- `latitude` (double?) - GPS latitude coordinate
- `longitude` (double?) - GPS longitude coordinate

**New Methods:**
- `hasGeoLocation` getter - Returns true if both lat/lng are set
- Updated `toJson()` - Only includes lat/lng if they're not null
- Updated `fromJson()` - Safely parses lat/lng from JSON
- Updated `copyWith()` - Allows updating lat/lng

### 2. New Admin Screen: Geolocation Mapping

**File:** `frontend/lib/admin/geolocation_mapping_screen.dart`

**Features:**
- Floor selector (switch between floors 1, 2, 3)
- Interactive map showing all nodes
- Mobile-first design with bottom controls
- 3-step workflow:
  1. Get current GPS location (uses device GPS)
  2. Select a node on the map
  3. Assign GPS coordinates to the selected node

**Visual Indicators:**
- **Green nodes** - Have GPS coordinates assigned (filled circle with glow)
- **Blue hollow nodes** - No GPS coordinates (hollow circle)
- **Purple pulsing node** - Currently selected node (large pulsing circle)

**Bottom Control Panel:**
- **Status Row:**
  - GPS Status: Shows if GPS is acquired, accuracy in meters
  - Node Status: Shows selected node and its location name
  - Statistics: Count of nodes with GPS coordinates
- **Action Buttons:**
  - "Get GPS" button: Acquires current GPS location
  - "Assign" button: Assigns GPS to selected node (enabled when both GPS and node are ready)

### 3. Admin Dashboard Integration

**File:** `frontend/lib/admin_dashboard_screen.dart`

Added new card:
- **Title:** "Geolocation Mapping"
- **Subtitle:** "Assign GPS coordinates to nodes"
- **Icon:** GPS icon
- **Color:** Pink (#E91E63)
- **Route:** `/admin/geolocation_mapping`

### 4. Backend Compatibility

The backend already supports storing arbitrary fields in nodes, so lat/lng will be:
- Saved to MongoDB when graph is saved
- Retrieved when graph is loaded
- Preserved during all graph operations

### 5. Dependencies Added

**File:** `frontend/pubspec.yaml`

Added: `geolocator: ^13.0.2`

This package provides:
- GPS location access
- Permission handling
- High accuracy positioning

## How to Use

### For Admins:

1. **Open Admin Dashboard**
   - Login as admin
   - Click "Geolocation Mapping" card

2. **Select Floor**
   - Choose which floor to work on (1, 2, or 3)

3. **Get Your GPS Location**
   - Stand at the exact physical location of a node
   - Click "Get GPS" button in the bottom control panel
   - Wait for GPS to acquire (shows accuracy in meters)
   - GPS status indicator turns green when ready

4. **Select Node on Map**
   - Tap the node on the map that corresponds to your current location
   - Node will highlight in purple

5. **Assign Coordinates**
   - Click "Assign" button in the bottom control panel
   - Button is only enabled when both GPS and node are selected
   - GPS coordinates are saved to that node
   - Node turns green with glow effect to indicate it has GPS data
   - Selection and GPS are cleared, ready for next assignment

6. **Repeat**
   - Move to another location
   - Get new GPS coordinates
   - Select different node
   - Assign

### Permissions Required:

**Android:**
- Location permission (requested automatically)
- GPS must be enabled

**iOS:**
- Location permission (requested automatically)
- Location services must be enabled

## Data Structure

### GraphNode with GPS:

```json
{
  "id": "node_123",
  "x": 0.5,
  "y": 0.3,
  "label": "",
  "dataset_location": "Room 101",
  "is_default": false,
  "latitude": 12.934567,
  "longitude": 77.612345
}
```

### GraphNode without GPS:

```json
{
  "id": "node_456",
  "x": 0.6,
  "y": 0.4,
  "label": "",
  "dataset_location": null,
  "is_default": false
}
```

Note: `latitude` and `longitude` are omitted if null (not included in JSON).

## Future Use Cases

This GPS data can be used for:

1. **Outdoor-to-Indoor Transition**
   - When user approaches building, switch from GPS to WiFi positioning
   - Use nearest GPS-mapped node as entry point

2. **Multi-Building Navigation**
   - Navigate between buildings using GPS
   - Navigate inside buildings using WiFi

3. **Augmented Reality**
   - Overlay indoor map on real-world view
   - Use GPS to align map with physical space

4. **Location Verification**
   - Verify WiFi predictions against GPS when outdoors
   - Improve model accuracy near windows/entrances

5. **Emergency Services**
   - Provide GPS coordinates for emergency response
   - Help first responders locate specific rooms

## Technical Notes

### GPS Accuracy:
- Typical accuracy: 3-10 meters outdoors
- Poor accuracy indoors (10-50 meters)
- Best results near windows or outdoors

### Best Practices:
- Map nodes near building entrances (best GPS signal)
- Map nodes near windows (better GPS signal)
- Take multiple readings and average if needed
- Map at least 2-3 nodes per floor for reference

### Data Persistence:
- GPS coordinates stored in MongoDB
- Preserved during graph edits
- Included in graph backups
- Not affected by node position changes

## Files Modified

1. `frontend/lib/models/graph_models.dart` - Added lat/lng fields
2. `frontend/lib/admin/floor_plan_screen.dart` - Preserve lat/lng when saving
3. `frontend/lib/admin/geolocation_mapping_screen.dart` - New screen (created)
4. `frontend/lib/admin_dashboard_screen.dart` - Added dashboard card
5. `frontend/lib/main.dart` - Added route
6. `frontend/pubspec.yaml` - Added geolocator dependency

## Installation

Run these commands:

```bash
cd frontend
flutter pub get
flutter run
```

## Testing

1. Login as admin (admin@admin.com / KCETADMIN)
2. Go to Admin Dashboard
3. Click "Geolocation Mapping"
4. Grant location permissions when prompted
5. Click "Get My Location"
6. Select a node on the map
7. Click "Assign to Node"
8. Verify node turns green
9. Check statistics panel shows updated count

## UI Design

### Mobile-First Approach:
- Controls positioned at bottom for easy thumb access
- Horizontal layout for status indicators
- Large touch targets for buttons
- Compact information display
- Responsive design adapts to screen size

### Color Scheme:
- **Blue (#2979FF)** - Primary actions, unassigned nodes
- **Green (#00C853)** - Success states, GPS-assigned nodes
- **Purple (#7C4DFF)** - Selected node highlight
- **Dark theme** - Reduces eye strain during extended use

## Status

✅ **COMPLETE** - Feature fully implemented with mobile-first design and ready to use!

---

**Version:** 1.0.1  
**Date:** March 29, 2026  
**Feature Type:** Admin Tool  
**Design:** Mobile-First

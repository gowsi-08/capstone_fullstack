# FindMyWay - User Guide
## Indoor Navigation Made Simple

---

## 📱 What is FindMyWay?

FindMyWay is an indoor navigation app that helps you find your way inside buildings where GPS doesn't work. Just like Google Maps helps you navigate outdoors, FindMyWay guides you inside buildings using WiFi signals to determine your location.

### Who is this for?
- Students navigating campus buildings
- Visitors finding specific rooms or offices
- Anyone who needs directions inside large buildings

---

## 🚀 Getting Started

### Installation

1. Download the FindMyWay APK file
2. On your Android device, go to Settings → Security
3. Enable "Install from Unknown Sources" or "Allow from this source"
4. Open the APK file and tap "Install"
5. Once installed, open the FindMyWay app

### First Time Setup

When you first open the app, you'll see the login screen with the FindMyWay logo.

---

## 🔐 Logging In

### For Students

1. Select the "Student" tab at the top
2. Enter your roll number (e.g., 22ucs001)
3. Enter your password (same as your roll number)
4. Tap "SIGN IN"

**Example:**
- Username: `22ucs001`
- Password: `22ucs001`

**Valid Roll Numbers:** 22ucs001 to 22ucs180

### For Administrators

1. Select the "Admin" tab at the top
2. Enter admin email: `admin@admin.com`
3. Enter password: `KCETADMIN`
4. Tap "ADMIN LOGIN"

### Guest Access

If you don't have login credentials, you can tap "Continue as Guest" at the bottom of the login screen. Guest users have limited features but can still view the map and search for locations.

---

## 🗺️ Main Map Screen

After logging in, you'll see the main map screen showing your building's floor plan.

### Understanding the Interface

**Top Bar:**
- Floor selector (L1, L2, L3) - Switch between floors
- Search bar - Find locations quickly
- Settings icon (Admin only) - Access admin dashboard
- Account icon - View profile and logout

**Map Area:**
- Interactive floor plan you can zoom and pan
- Location markers showing available destinations
- Your current location (when detected)
- Navigation path (when directions are active)

**Bottom Area:**
- Current location card - Shows where you are
- Floating action button (FAB) - Track your location

---

## 📍 Finding Your Current Location

### How It Works

FindMyWay uses WiFi signals around you to determine your location. The app scans nearby WiFi networks and compares their signal strengths to a database to figure out where you are.

### Tracking Your Location

1. Make sure WiFi is enabled on your device
2. Tap the blue location button (FAB) at the bottom right
3. The button turns green and shows a GPS icon
4. The app will scan WiFi signals every 2 seconds
5. Your location appears on the map with a pulsing marker
6. The current location card shows your position

**Location Card States:**

- **"Not detected yet"** - No location found yet, keep scanning
- **"You are at: [Location Name]"** - You're at a known location
- **"Predicted: Unknown Area (approx.)"** - You're in an unmapped area
- **"Live" badge** - Location tracking is active

### Stopping Location Tracking

Tap the green GPS button again to stop continuous tracking. The button returns to blue.

---

## 🔍 Searching for Locations

### Using the Search Bar

1. Tap the search bar at the top
2. Start typing a location name (e.g., "Room 101")
3. A dropdown list shows matching locations
4. Each result shows:
   - Location name
   - Floor number
   - Number of WiFi records (data quality indicator)
5. Tap a location to view it on the map

### What Happens When You Select a Location

- The map automatically switches to the correct floor
- The map zooms to show the selected location
- A marker appears at the destination
- The location is highlighted

---

## 🧭 Getting Directions

### Step-by-Step Navigation

1. Search for your destination using the search bar
2. Tap the location from the dropdown list
3. A "Get Directions" button appears
4. Tap "Get Directions"
5. Choose your starting point:
   - **"Current Location"** - Start from where you are now
   - **"Choose Location"** - Pick a different starting point

### Using Current Location

1. Select "Current Location"
2. The app scans WiFi to find where you are
3. Wait a moment for location detection
4. The navigation path appears on the map
5. Follow the blue line to your destination

### Choosing a Different Starting Point

1. Select "Choose Location"
2. A list of all available locations appears
3. Tap the location you want to start from
4. The navigation path appears on the map

### Understanding the Navigation Path

- **Blue animated line** - Your route to follow
- **Green pulsing marker** - Your current location
- **Red pulsing marker** - Your destination
- **Distance and time** - Shown in a toast message

### Tips for Navigation

- The path shows the walkable route through hallways and corridors
- Follow the blue line on the map
- If you get lost, tap the location button to see where you are
- The path updates if you move to a different location

---

## 🏢 Switching Floors

### How to Change Floors

1. Tap the floor selector button (shows "L1", "L2", or "L3")
2. Select the floor you want to view
3. The map updates to show that floor's layout

**Note:** Navigation paths only work within the same floor. If your destination is on a different floor, you'll need to:
1. Navigate to the stairs/elevator on your current floor
2. Go to the destination floor
3. Search for your destination again on that floor

---

## ⚙️ Settings and Account

### Accessing Your Account

1. Tap the account icon (person icon) in the top right
2. View your username and role
3. Tap "Logout" to sign out

### Permissions

The app needs these permissions to work:
- **Location** - Required for WiFi scanning
- **WiFi** - Required to detect your position
- **Internet** - Required to communicate with the server

If the app asks for permissions, tap "Allow" to enable full functionality.

---

## 🛠️ Troubleshooting

### "No Wi-Fi signals found"

**Problem:** The app can't detect WiFi networks.

**Solutions:**
1. Make sure WiFi is turned on in your device settings
2. Check that location permissions are granted
3. Move to an area with WiFi coverage
4. Restart the app and try again

### "Could not predict location"

**Problem:** The app can't determine where you are.

**Solutions:**
1. Check your internet connection
2. Make sure you're inside the building
3. Wait a few seconds and try again
4. Move to a different area with better WiFi coverage

### "Model needs retraining"

**Problem:** The location detection system needs updating.

**Solutions:**
1. This is an admin issue - contact your administrator
2. The admin needs to retrain the model from the admin dashboard
3. Wait for the admin to fix this before using location features

### "No walkable path found"

**Problem:** The app can't find a route to your destination.

**Solutions:**
1. Make sure both locations are on the same floor
2. Check that the destination is a valid location
3. Try selecting a different starting point
4. Contact admin if the problem persists

### App is slow or unresponsive

**Solutions:**
1. Close and restart the app
2. Check your internet connection
3. Clear the app cache in device settings
4. Reinstall the app if problems continue

### Location tracking stops working

**Solutions:**
1. Tap the location button again to restart tracking
2. Check that WiFi is still enabled
3. Make sure you haven't moved out of WiFi range
4. Restart the app

---

## 💡 Tips and Best Practices

### For Best Results

1. **Keep WiFi On:** The app needs WiFi to work, even if you're not connected to a network
2. **Stay Still When Scanning:** Don't move while the app is detecting your location
3. **Wait for Detection:** Location detection takes 1-2 seconds
4. **Use Tracking Mode:** Enable continuous tracking when navigating
5. **Check Your Floor:** Make sure you're viewing the correct floor

### Battery Saving

- Turn off location tracking when you're not navigating
- Close the app when you're done using it
- Don't leave tracking running in the background

### Getting Accurate Locations

- The more WiFi networks nearby, the more accurate your location
- Indoor areas with good WiFi coverage work best
- Outdoor areas or areas with weak WiFi may not work well

---

## 🎯 Common Use Cases

### Scenario 1: Finding a Classroom

1. Open the app and log in
2. Search for the classroom (e.g., "Room 205")
3. Tap the result to see it on the map
4. Note which floor it's on
5. Navigate there using the map

### Scenario 2: Getting Directions from Your Current Location

1. Make sure WiFi is on
2. Tap the blue location button to find where you are
3. Search for your destination
4. Tap "Get Directions"
5. Select "Current Location"
6. Follow the blue path on the map

### Scenario 3: Planning a Route Before You Go

1. Search for your destination
2. Tap "Get Directions"
3. Select "Choose Location"
4. Pick your starting point
5. View the route to plan your path

### Scenario 4: Exploring the Building

1. Switch between floors using the floor selector
2. Zoom and pan around the map
3. Tap location markers to see what's there
4. Search for specific areas of interest

---

## 📊 Understanding Location Accuracy

### Location Status Indicators

**"You are at: [Location Name]"**
- High confidence
- You're at a known, mapped location
- Navigation will work from here

**"Predicted: Unknown Area (approx.)"**
- Lower confidence
- You're in an area without specific mapping
- The marker shows an approximate position
- Navigation may not work from here

**"Not detected yet"**
- No location found
- Keep scanning or move to a different area

### Why Location Detection Might Be Inaccurate

- You're in an area with few WiFi networks
- WiFi signals are weak or blocked
- You're near the edge of the building
- The training data for that area is limited
- You're in a newly constructed area not yet mapped

---

## 🔒 Privacy and Data

### What Data Does the App Collect?

- WiFi network names and signal strengths (for location detection)
- Your selected destinations (for navigation)
- Login credentials (stored securely)

### What Data is NOT Collected?

- Your personal information
- Your browsing history
- Your contacts or photos
- Your exact GPS coordinates
- Any data when you're not using the app

### Data Security

- All communication with the server is encrypted
- Passwords are hashed and never stored in plain text
- WiFi data is only used for location detection
- No data is shared with third parties

---

## 📞 Getting Help

### If You Need Assistance

1. **Check this guide first** - Most questions are answered here
2. **Try the troubleshooting section** - Common problems and solutions
3. **Contact your administrator** - For technical issues or access problems
4. **Restart the app** - Many issues are fixed by restarting

### Reporting Problems

If you encounter a bug or issue:
1. Note what you were doing when the problem occurred
2. Take a screenshot if possible
3. Contact your administrator with details
4. Include your username and the time of the issue

---

## 🎓 Frequently Asked Questions (FAQ)

### Q: Do I need an internet connection?

**A:** Yes, the app needs internet to communicate with the server for location detection and navigation.

### Q: Does the app work outdoors?

**A:** No, FindMyWay is designed for indoor navigation only. Use Google Maps for outdoor navigation.

### Q: Why do I need WiFi if I have mobile data?

**A:** The app uses WiFi signals to determine your location, not for internet access. You need both WiFi (for positioning) and internet (mobile data or WiFi connection) for the app to work.

### Q: Can I use the app on multiple floors at once?

**A:** No, you can only view one floor at a time. Switch floors using the floor selector.

### Q: How accurate is the location detection?

**A:** Accuracy depends on WiFi coverage. In areas with good WiFi, accuracy is typically within 3-5 meters.

### Q: Can I save favorite locations?

**A:** Not currently. Use the search feature to quickly find locations you visit often.

### Q: Does location tracking drain my battery?

**A:** Continuous tracking uses more battery. Turn it off when you're not navigating to save power.

### Q: What if my destination is on a different floor?

**A:** Navigate to the stairs/elevator on your current floor, go to the destination floor, then search for your destination again.

### Q: Can I use the app offline?

**A:** No, the app requires an internet connection to work.

### Q: Why does the app ask for location permissions?

**A:** Android requires location permissions for WiFi scanning. The app doesn't use GPS.

---

## 🆕 What's New

### Current Version: 1.0.0

**Features:**
- Real-time indoor positioning
- Turn-by-turn navigation
- Interactive floor plans
- Location search
- Continuous location tracking
- Professional map markers
- Automatic model updates

---

## 📝 Quick Reference

### Login Credentials

| Role | Username | Password |
|------|----------|----------|
| Student | 22ucs001 to 22ucs180 | Same as username |
| Admin | admin@admin.com | KCETADMIN |
| Guest | N/A | Tap "Continue as Guest" |

### Button Guide

| Button | Function |
|--------|----------|
| Blue location button | Start location tracking |
| Green GPS button | Stop location tracking |
| Floor selector (L1/L2/L3) | Switch floors |
| Search bar | Find locations |
| Account icon | Logout |
| Settings icon (Admin) | Admin dashboard |

### Status Indicators

| Indicator | Meaning |
|-----------|---------|
| Green pulsing marker | Your current location |
| Red pulsing marker | Selected destination |
| Blue animated line | Navigation path |
| Purple pins | Available locations |
| "Live" badge | Tracking active |

---

## 🎉 Enjoy Using FindMyWay!

We hope this guide helps you navigate your building with ease. FindMyWay is designed to make indoor navigation simple and intuitive. If you have any questions or feedback, please contact your administrator.

**Happy navigating!** 🗺️✨

---

**Version:** 1.0.0  
**Last Updated:** 2024  
**App Name:** FindMyWay  
**Developer:** Indoor Navigation Team

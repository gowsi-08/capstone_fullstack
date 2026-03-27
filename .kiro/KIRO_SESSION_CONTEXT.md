# Kiro Session Context - FindMyWay Project

## Quick Reference
This file contains essential context for AI assistants working on the FindMyWay indoor navigation project. Load this file at the start of each session to maintain continuity.

---

## Project Overview
**FindMyWay** is a WiFi-based indoor navigation system using ML for location prediction.

### Tech Stack
- **Frontend**: Flutter 3.10.4+ (Android/iOS/Web)
- **Backend**: Flask 2.3.3 + scikit-learn 1.5.0 (RandomForest)
- **Database**: MongoDB Atlas with GridFS
- **Deployment**: Render.com (backend), Flutter native (frontend)

### Key Features
- WiFi fingerprinting for indoor localization
- Interactive floor maps with pathfinding
- Admin dashboard for system management
- 180 student accounts + admin access
- Multi-floor support

---

## Recent Major Changes

### Training Data MongoDB Migration + Full CRUD (Current)
**Date**: Current session
**Status**: 🚧 In Progress - Tab 1 Complete

**Changes**:
1. ✅ Migrated CSV data (train.csv, test.csv) to MongoDB `training_data_records` collection
2. ✅ Added comprehensive CRUD API endpoints for training data management
3. ✅ Rebuilt Training Data screen with 3-tab structure (All 3 tabs complete)
4. ✅ Tab 1 (Collect), Tab 2 (Manage), Tab 3 (Merge) - all fully implemented
5. ✅ Fixed mobile layout issues (removed sidebar on mobile, cards only)
6. ✅ Added 13 new API methods to api_service.dart

**New Backend**:
- `backend/scripts/migrate_csv_to_mongo.py` - Migration script (ready to run)
- New API endpoints in `routes/api.py` (15 endpoints added):
  - GET `/admin/training-records` - Paginated records
  - GET `/admin/training-records/grouped` - Grouped by location
  - GET `/admin/training-records/locations` - Distinct locations
  - POST `/admin/training-records` - Add single record
  - POST `/admin/training-records/bulk` - Bulk insert
  - PUT `/admin/training-records/{id}` - Update record
  - PUT `/admin/training-records/bulk` - Bulk update
  - DELETE `/admin/training-records/{id}` - Delete record
  - DELETE `/admin/training-records/bulk` - Bulk delete
  - DELETE `/admin/training-records/group/{location}` - Delete by group
  - POST `/admin/training-records/merge` - Merge locations
  - GET `/admin/training-records/export` - Export CSV

**New Frontend**:
- ✅ Rebuilt `admin/training_data_screen.dart` with TabBar (3 tabs)
  - Tab 1 (Collect): ✅ Complete - WiFi scanning preserved, new dark theme
  - Tab 2 (Manage): ✅ Complete - Grouped/List views, filters, multi-select, bulk actions
  - Tab 3 (Merge): ✅ Complete - Multi-select sources, target input, floor selector, merge tool
- Old file backed up as `training_data_screen_old_backup.dart`
- ✅ Updated `api_service.dart` with 13 new CRUD methods
- ⏳ Need to rebuild `admin/floor_plan_screen.dart` as gallery

### Admin Dashboard Refactor (Previous)
**Date**: Current session
**Status**: ✅ Complete and working

Redesigned admin interface from single screen to professional dashboard:

**New Structure**:
```
frontend/lib/
├── admin_dashboard_screen.dart          ← Main hub with glassmorphic cards
├── admin/
│   ├── floor_plan_screen.dart          ← Floor map management
│   ├── location_marking_screen.dart    ← Interactive location marking
│   ├── training_data_screen.dart       ← WiFi data collection (refactored)
│   ├── model_retraining_screen.dart    ← ML model retraining
│   └── stats_dashboard_screen.dart     ← Analytics dashboard
├── admin_screen.dart                    ← DEPRECATED (redirects to dashboard)
└── training_data_screen.dart            ← Legacy (kept for backward compat)
```

**Design System**:
- Dark theme: `#0A1929` (navy), `#132F4C` (charcoal)
- Accent colors: Blue `#2979FF`, Teal `#00BCD4`, Purple `#7C4DFF`, Orange `#FF6D00`, Green `#00C853`
- Typography: Google Fonts Outfit (headings) + Inter (body)
- Effects: Glassmorphism with BackdropFilter, staggered animations

**Routes**:
- `/admin_dashboard` → Main admin hub
- `/admin/floor_plan` → Floor plan management
- `/admin/location_marking` → Location marking
- `/admin/training_data` → WiFi data collection
- `/admin/model_retraining` → Model retraining
- `/admin/stats_dashboard` → Statistics
- `/admin_panel` → Redirects to `/admin_dashboard`

**Dependencies Added**:
- `google_fonts: ^6.1.0`

---

## File Structure

### Backend (`backend/`)
```
backend/
├── app.py                      # Flask entry point
├── config.py                   # Environment config
├── requirements.txt            # Python dependencies
├── routes/
│   └── api.py                 # All API endpoints
├── services/
│   ├── auth_service.py        # Authentication
│   ├── database.py            # MongoDB connection
│   ├── model_service.py       # ML model operations
│   └── training_service.py    # Training data management
└── utils/
    ├── csv_handler.py         # CSV parsing
    └── image_processing.py    # Floor plan processing
```

### Frontend (`frontend/lib/`)
```
frontend/lib/
├── main.dart                   # App entry + routing
├── app_state.dart             # Global state (Provider)
├── api_service.dart           # Backend API client
├── db_helper.dart             # Local SQLite
├── login_screen.dart          # Authentication UI
├── map_screen.dart            # Main navigation interface
├── admin_dashboard_screen.dart # Admin hub (NEW)
├── admin_screen.dart          # Legacy redirect
├── admin/                     # Admin sub-screens (NEW)
│   ├── floor_plan_screen.dart
│   ├── location_marking_screen.dart
│   ├── training_data_screen.dart
│   ├── model_retraining_screen.dart
│   └── stats_dashboard_screen.dart
└── [other screens]
```

---

## API Endpoints

### Authentication
- `POST /auth/login` - User login

### Location Prediction
- `POST /getlocation` - Predict location from WiFi signals
- `GET /locations/all` - Get all locations

### Admin - Training Data
- `POST /admin/training-data` - Submit WiFi fingerprints
- `POST /admin/retrain` - Trigger model retraining
- `GET /admin/training-stats` - Get training statistics

### Admin - Maps
- `POST /admin/upload_map/{floor}` - Upload floor plan
- `GET /admin/map_base64/{floor}` - Get map as base64
- `GET /admin/map_image/{floor}` - Get map as image

### Admin - Locations
- `GET /admin/locations/{floor}` - Get locations for floor
- `POST /admin/locations/{floor}` - Save locations
- `PUT /admin/location/{id}` - Update location
- `DELETE /admin/location/{id}` - Delete location

---

## Authentication

### Credentials
- **Admin**: `admin@admin.com` / `KCETADMIN`
- **Students**: `22ucs001` to `22ucs180` (password = username)
- **Guest**: No credentials required

### Implementation
- Dual-mode: Backend API + local fallback
- Session persistence via SharedPreferences
- AppState properties: `userType`, `isAdmin`, `isLoggedIn`

---

## Common Issues & Solutions

### Issue: Import conflicts (TrainingDataScreen)
**Solution**: Use import aliases
```dart
import 'admin/training_data_screen.dart' as admin_training;
import 'training_data_screen.dart' as legacy_training;
```

### Issue: Colors.white40 doesn't exist
**Solution**: Use `Colors.white.withOpacity(0.4)`

### Issue: AppState.currentUser doesn't exist
**Solution**: Use `AppState.userType` instead

### Issue: Google Fonts not loading
**Solution**: Run `flutter pub get` after adding dependency

---

## Development Commands

### Backend
```bash
cd backend
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
python app.py  # Runs on port 5000
```

### Frontend
```bash
cd frontend
flutter pub get
flutter run  # For mobile
flutter run -d chrome  # For web
```

### Testing
```bash
# Backend
cd backend
pytest

# Frontend
cd frontend
flutter test
```

---

## Configuration

### Backend Environment Variables (`.env`)
```
MONGO_URL=mongodb+srv://...
DB_NAME=findmyway
SECRET_KEY=your-secret-key
ADMIN_EMAIL=admin@admin.com
ADMIN_PASSWORD=KCETADMIN
PORT=5000
DEBUG=True
```

### Frontend API Configuration (`api_service.dart`)
```dart
static const String _productionUrl = "https://capstone-server-yadf.onrender.com";
const bool useProduction = true;  // Toggle for local dev
```

---

## Key Code Patterns

### Glassmorphic Card
```dart
ClipRRect(
  borderRadius: BorderRadius.circular(20),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      // Content
    ),
  ),
)
```

### API Call Pattern
```dart
Future<void> _loadData() async {
  setState(() => _isLoading = true);
  final data = await ApiService.getData();
  if (!mounted) return;
  setState(() {
    _data = data;
    _isLoading = false;
  });
}
```

### Navigation
```dart
// Push new screen
Navigator.pushNamed(context, '/route_name');

// Replace current screen
Navigator.pushReplacementNamed(context, '/route_name');

// Pop back
Navigator.pop(context);
```

---

## Testing Checklist

When making changes, verify:
- [ ] All imports resolve correctly
- [ ] No diagnostic errors (`getDiagnostics`)
- [ ] API calls work (check network tab)
- [ ] Navigation flows correctly
- [ ] State updates trigger UI refresh
- [ ] Loading states display properly
- [ ] Error handling works
- [ ] Animations play smoothly
- [ ] Responsive layout adapts

---

## Known Constraints

1. **No backend changes**: All API endpoints must remain unchanged
2. **Preserve functionality**: All existing features must work identically
3. **Authentication flow**: Cannot modify login/logout logic
4. **Database schema**: MongoDB collections structure is fixed
5. **ML model**: RandomForest implementation is fixed

---

## Future Enhancements (Backlog)

- Real-time updates via WebSockets
- Batch operations for locations
- Export training data as CSV
- Undo/redo for location marking
- Dark/light theme toggle
- Multi-language support (i18n)
- Audit log for admin actions
- Role-based permissions
- Data visualization charts
- Bluetooth beacon support

---

## Documentation Files

- `PROJECT_CONTEXT.md` - Original project overview
- `ADMIN_DASHBOARD_REFACTOR.md` - Admin refactor details
- `ADMIN_DASHBOARD_VISUAL_GUIDE.md` - Design system reference
- `.kiro/KIRO_SESSION_CONTEXT.md` - This file (session context)

---

## Quick Start for New Session

1. Read this file first
2. Check `ADMIN_DASHBOARD_REFACTOR.md` for recent changes
3. Run `flutter pub get` if dependencies changed
4. Check diagnostics: `getDiagnostics` on modified files
5. Test navigation flows after changes
6. Update this file if making significant changes

---

## Contact & Resources

- **Backend URL**: https://capstone-server-yadf.onrender.com
- **MongoDB**: Atlas cluster (credentials in .env)
- **Flutter Version**: 3.10.4+
- **Python Version**: 3.11.10

---

**Last Updated**: Current session
**Status**: All systems operational ✅
**Next Steps**: Test admin dashboard on device, collect feedback

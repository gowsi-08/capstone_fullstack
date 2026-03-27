# MongoDB Migration & Training Data CRUD - Implementation Guide

## Status: 🚧 In Progress

This document tracks the implementation of the comprehensive training data management system.

## Completed ✅

### Backend
1. ✅ Created `backend/scripts/migrate_csv_to_mongo.py` - Migration script
2. ✅ Added 15 new API endpoints in `backend/routes/api.py`:
   - GET `/admin/training-records` - Paginated records with filters
   - GET `/admin/training-records/grouped` - Grouped by location
   - GET `/admin/training-records/locations` - Distinct locations list
   - POST `/admin/training-records` - Add single record
   - POST `/admin/training-records/bulk` - Bulk insert
   - PUT `/admin/training-records/{id}` - Update single
   - PUT `/admin/training-records/bulk` - Bulk update
   - DELETE `/admin/training-records/{id}` - Delete single
   - DELETE `/admin/training-records/bulk` - Bulk delete
   - DELETE `/admin/training-records/group/{location}` - Delete by group
   - POST `/admin/training-records/merge` - Merge locations
   - GET `/admin/training-records/export` - Export as CSV

### Frontend
1. ✅ Fixed mobile layout issues (removed sidebar on mobile)
2. ✅ Fixed BoxShadow type cast error in location_marking_screen.dart

## In Progress 🚧

### Backend
- [ ] Update `training_service.py` to read from MongoDB instead of CSV
- [ ] Update `model_service.py` to build feature matrix from MongoDB
- [ ] Test all new API endpoints

### Frontend
- [ ] Rebuild `admin/training_data_screen.dart` with 3 tabs
- [ ] Rebuild `admin/floor_plan_screen.dart` as gallery
- [ ] Update `api_service.dart` with new methods
- [ ] Add shimmer loading effects
- [ ] Add multi-select functionality
- [ ] Add merge UI

## Next Steps

### 1. Run Migration Script
```bash
cd backend
python scripts/migrate_csv_to_mongo.py
```

### 2. Update Training Service
Modify `backend/services/training_service.py` to:
- Write new data to MongoDB instead of CSV
- Read from MongoDB for retraining
- Keep CSV as backup/export format

### 3. Update Model Service  
Modify `backend/services/model_service.py` to:
- Load training data from MongoDB
- Build feature matrix from MongoDB records
- Cache BSSID list from MongoDB

### 4. Frontend Implementation Priority

**Phase 1: API Service (Critical)**
- Add all new API methods to `api_service.dart`
- Test connectivity with backend

**Phase 2: Training Data Screen (High Priority)**
- Tab 1: Keep existing collect functionality
- Tab 2: Implement manage view with filters
- Tab 3: Implement merge tool

**Phase 3: Floor Plan Screen (Medium Priority)**
- Gallery view with floor cards
- Expand view with InteractiveViewer
- Add floor functionality

## Design Specifications

### Training Data Screen Tabs

**Tab 1: Collect**
- Preserve all existing WiFi scan functionality
- Update styling to match dark theme
- Submit button calls new MongoDB endpoint

**Tab 2: Manage**
- Filter chips: Floor (All/1/2/3), Source (All/Train/Test)
- Search bar for location filtering
- Toggle: List view ↔ Grouped view
- Grouped view: ExpansionTile per location
- List view: Flat paginated list
- Multi-select: Long press activates checkboxes
- Bulk actions: Delete, Change Location, Change Floor, Export

**Tab 3: Merge**
- Left panel: Multi-select source locations
- Right panel: Target location input
- Floor selector
- Delete sources toggle
- Preview count
- Confirm button

### Floor Plan Screen Gallery

**Gallery View**
- 2-column grid on mobile, 3 on tablet
- Each card shows:
  - Floor map thumbnail
  - Floor number badge
  - Location count badge
  - Upload placeholder if no map
- Tap to expand

**Expanded View**
- Full-screen InteractiveViewer
- Hero animation from card
- Bottom action bar:
  - Replace Map
  - View Locations
  - Download Map
- Close button top-right

**Add Floor FAB**
- Bottom-right floating button
- Opens bottom sheet:
  - Floor number input
  - Image picker
  - Upload button with progress

## Testing Checklist

### Backend
- [ ] Migration script runs without errors
- [ ] All new endpoints return correct data
- [ ] Pagination works correctly
- [ ] Filters apply properly
- [ ] Bulk operations work
- [ ] Merge functionality works
- [ ] Export generates valid CSV

### Frontend
- [ ] All API calls succeed
- [ ] Loading states display
- [ ] Error handling works
- [ ] Multi-select activates
- [ ] Bulk actions execute
- [ ] Merge preview accurate
- [ ] Gallery loads all floors
- [ ] Expand animation smooth
- [ ] Upload progress shows

## Known Issues

1. ✅ FIXED: RenderFlex overflow on mobile (removed sidebar)
2. ✅ FIXED: BoxShadow type cast error (removed Container wrapper)
3. ⚠️  TODO: Need to update training_service.py for MongoDB
4. ⚠️  TODO: Need to update model_service.py for MongoDB

## Migration Notes

- CSV files (train.csv, test.csv) are kept as backup
- MongoDB collection: `training_data_records`
- Unique key prevents duplicates: `{bssid}_{location}_{floor}_{signal}`
- Indexes created on: location+floor, bssid, source, created_at
- All timestamps stored as UTC ISODate

## API Response Formats

### GET /admin/training-records
```json
{
  "records": [...],
  "total": 245,
  "page": 1,
  "limit": 50,
  "pages": 5,
  "filters": {"floor": 1, "location": null, "source": "train"}
}
```

### GET /admin/training-records/grouped
```json
{
  "Room 101 (Floor 1)": {
    "location": "Room 101",
    "floor": 1,
    "count": 45,
    "bssids": ["aa:bb:cc:dd:ee:ff", ...],
    "bssid_count": 12,
    "avg_signal": -65.5,
    "records": [...]
  }
}
```

### POST /admin/training-records/merge
```json
{
  "success": true,
  "merged": 78,
  "target": "Combined Room"
}
```

## File Sizes

- `migrate_csv_to_mongo.py`: ~200 lines
- New API endpoints: ~400 lines added to `api.py`
- `training_data_screen.dart`: ~1000 lines (estimated)
- `floor_plan_screen.dart`: ~600 lines (estimated)
- `api_service.dart`: +300 lines (new methods)

## Estimated Completion Time

- Backend updates: 2-3 hours
- Frontend Training Data screen: 4-5 hours
- Frontend Floor Plan screen: 2-3 hours
- Testing & bug fixes: 2-3 hours
- **Total**: 10-14 hours

## Priority Order

1. **Critical**: Run migration script, test MongoDB connection
2. **High**: Update training_service.py and model_service.py
3. **High**: Add API methods to api_service.dart
4. **Medium**: Rebuild training_data_screen.dart Tab 2 (Manage)
5. **Medium**: Rebuild floor_plan_screen.dart (Gallery)
6. **Low**: Add Tab 3 (Merge) to training_data_screen.dart
7. **Low**: Polish animations and loading states

## Next Session TODO

1. Run migration script and verify data in MongoDB
2. Update training_service.py to use MongoDB
3. Update model_service.py to use MongoDB
4. Test model retraining with MongoDB data
5. Begin frontend API service updates
6. Start rebuilding training_data_screen.dart

---

**Last Updated**: Current session
**Status**: Backend API complete, Frontend pending

# Model Retrain Guide - Fix Feature Mismatch Error

## Problem
The WiFi location prediction is failing with error:
```
"X has 67 features, but KNeighborsClassifier is expecting 66 features as input."
```

This happens when:
- New WiFi access points (BSSIDs) are added to the training data
- The model was trained with a different number of BSSIDs than currently exist in the database
- Training data has been updated but the model hasn't been retrained

## Solution: Retrain the Model

### Option 1: Using the Python Script (Recommended)

Run the retrain script from the backend directory:

```bash
cd backend
python trigger_retrain.py
```

This script will:
1. Check current training data statistics
2. Trigger model retraining on the production server
3. Wait for completion
4. Test prediction to verify it works

### Option 2: Using the Admin Dashboard

1. Open the Flutter app
2. Login as admin
3. Go to Admin Dashboard (gear icon in top right)
4. Navigate to "Training Data Management"
5. Click "Retrain Model" button
6. Wait for the success message

### Option 3: Using curl/API directly

```bash
curl -X POST https://capstone-server-yadf.onrender.com/admin/retrain
```

## How the Retrain Works

The retrain process:
1. Fetches all training data from MongoDB (`training_data_records` collection)
2. Extracts unique BSSIDs from the data
3. Creates a feature matrix where each row is a location scan and each column is a BSSID
4. Trains a KNeighborsClassifier model
5. Saves the model to `wifi_model.pkl`
6. Reloads the model in memory

## Verification

After retraining, test the prediction:

1. **Check logs**: Look for these messages in the backend logs:
   ```
   ✅ Model loaded successfully
   ✅ Loaded X unique BSSIDs from MongoDB
   ```

2. **Test in app**: Click the location button in the Flutter app
   - Should see: "📍 You are at: [Location Name]"
   - Should NOT see: "⚠️ Model needs retraining"

3. **Check feature count**: The number of BSSIDs should match between:
   - Training data in MongoDB
   - Model's expected features
   - Current WiFi scans

## Preventing This Issue

To avoid feature mismatch in the future:

1. **Retrain regularly**: After adding new training data, always retrain
2. **Consistent data**: Use the same WiFi environment for training and prediction
3. **Monitor BSSIDs**: Check training stats to see if new BSSIDs are being added

## Technical Details

### Model Service (`backend/services/model_service.py`)

The model service:
- Loads the trained model from `wifi_model.pkl`
- Loads all unique BSSIDs from MongoDB
- Creates feature vectors matching the training data structure
- Returns predictions or None if there's a mismatch

### Training Service (`backend/services/training_service.py`)

The training service:
- Fetches training data from MongoDB
- Splits into train/test sets
- Trains KNeighborsClassifier
- Evaluates accuracy
- Saves model to disk

### Error Handling

The frontend now detects feature mismatch errors and shows:
```
⚠️ Model needs retraining. Contact admin to retrain the model.
```

The backend logs detailed information:
```
❌ Prediction error: X has 67 features, but KNeighborsClassifier is expecting 66 features
   Model was trained with different number of features
   Current BSSIDs in database: 67
   Solution: Retrain the model with current data
```

## Troubleshooting

### Retrain doesn't fix the issue
- Wait 1-2 minutes for the model to fully reload
- Restart the backend server
- Check if training data exists in MongoDB

### Model file not found
- Run the retrain endpoint to create a new model
- Check if `wifi_model.pkl` exists in the backend directory

### Still getting errors after retrain
- Check backend logs for detailed error messages
- Verify MongoDB connection is working
- Ensure training data has multiple locations and scans

## Files Modified

### Backend
- `backend/services/model_service.py` - Added better error logging
- `backend/routes/api.py` - Enhanced logging for prediction endpoint
- `backend/trigger_retrain.py` - New script to trigger retrain

### Frontend
- `frontend/lib/api_service.dart` - Detect feature mismatch errors
- `frontend/lib/map_screen.dart` - Show helpful error message

## Next Steps

After retraining:
1. Test WiFi location prediction in the app
2. Verify current location is displayed correctly
3. Test navigation between locations
4. Monitor for any new errors

## Support

If issues persist:
1. Check backend server logs for detailed errors
2. Verify training data quality in MongoDB
3. Ensure WiFi scanning is working on the device
4. Contact the development team with error logs

# Quick Start: Graph-Based Navigation

## 🚀 Test the New Navigation System

### Prerequisites
- Backend running on port 5000
- Frontend running on device/emulator
- Admin account logged in
- At least one floor map uploaded

---

## Step 1: Create a Walkable Graph (5 minutes)

### Open Path Editor
1. Login as admin
2. Tap "Admin Dashboard"
3. Tap "Floor Plans & Navigation"
4. Tap "Floor 1" card
5. Tap "Edit Paths" button (top segmented control)

### Draw the Network
1. **Tap on walkable areas** to place nodes
   - Start at one end of a corridor
   - Tap along the corridor path
   - Tap at intersections
   - Tap near room entrances

2. **Nodes auto-connect** to the last selected node
   - Blue circles = nodes
   - Green circle = selected node
   - Blue lines = walkable paths

3. **Create a connected network**
   - Cover all corridors
   - Connect all rooms
   - Ensure no isolated sections

### Example Pattern
```
Room A ----o----o----o---- Junction ----o----o---- Room B
                            |
                            o
                            |
                            o
                            |
                         Room C
```

### Save
1. Tap "Save Graph" button (bottom)
2. Wait for success message
3. Graph is now stored in MongoDB

---

## Step 2: Verify Graph in Database

### Using MongoDB Compass
```javascript
// Connect to your MongoDB
// Database: your_db_name
// Collection: walkable_graph

// Find graph for floor 1
db.walkable_graph.findOne({floor: 1})

// Should see:
{
  "_id": ObjectId("..."),
  "floor": 1,
  "nodes": [
    {"id": "uuid-1", "x": 0.5, "y": 0.5, "label": ""},
    {"id": "uuid-2", "x": 0.6, "y": 0.6, "label": ""},
    ...
  ],
  "edges": [
    {"id": "edge-1", "from_node": "uuid-1", "to_node": "uuid-2", "weight": 0.141},
    ...
  ],
  "updated_at": ISODate("...")
}
```

### Using curl
```bash
curl http://localhost:5000/admin/graph/1
```

---

## Step 3: Test Pathfinding API

### Using curl
```bash
curl -X POST http://localhost:5000/navigation/path \
  -H "Content-Type: application/json" \
  -d '{
    "floor": 1,
    "from_location": "Room 101",
    "to_location": "Room 202"
  }'
```

### Expected Response
```json
{
  "path_nodes": [
    {"x": 0.34, "y": 0.56},
    {"x": 0.40, "y": 0.60},
    {"x": 0.45, "y": 0.65}
  ],
  "total_distance": 0.156,
  "estimated_seconds": 12,
  "found": true
}
```

### If No Path Found
```json
{
  "path_nodes": [],
  "total_distance": 0,
  "estimated_seconds": 0,
  "found": false,
  "error": "No path found between locations"
}
```

**Troubleshooting:**
- Ensure both locations exist in `locations` collection
- Verify graph is connected (no isolated nodes)
- Check that locations are on the same floor

---

## Step 4: Integrate with Map Screen (Next)

### Update `map_screen.dart`

Find the `_getDirections()` method and replace with:

```dart
void _getDirections() async {
  if (predictedRoom.isEmpty || selectedDestination.isEmpty) return;
  
  try {
    final uri = Uri.parse('${ApiService.baseUrl}/navigation/path');
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'floor': int.parse(currentFloor),
        'from_location': predictedRoom,
        'to_location': selectedDestination,
      }),
    );
    
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      
      if (data['found'] == true) {
        // Convert normalized coordinates to pixel coordinates
        final pathNodes = (data['path_nodes'] as List).map((n) {
          // Assuming map image is loaded and we know its dimensions
          // You'll need to get actual image dimensions
          final imageWidth = 2000.0; // Replace with actual width
          final imageHeight = 2000.0; // Replace with actual height
          
          return Offset(
            n['x'] * imageWidth,
            n['y'] * imageHeight,
          );
        }).toList();
        
        setState(() => _shortestPath = pathNodes);
        
        final seconds = data['estimated_seconds'];
        final minutes = (seconds / 60).ceil();
        
        Fluttertoast.showToast(
          msg: "Route found! Estimated time: ${minutes}min",
          backgroundColor: Colors.indigo,
          textColor: Colors.white,
        );
      } else {
        Fluttertoast.showToast(
          msg: data['error'] ?? "No path found between locations",
        );
      }
    }
  } catch (e) {
    print('Pathfinding error: $e');
    Fluttertoast.showToast(msg: "Failed to calculate route");
  }
}
```

### The existing `PathPainter` will automatically render the path!

---

## Step 5: Test End-to-End Navigation

### In the App
1. **Go to Map Screen**
   - Login as student or admin
   - Main screen shows map

2. **Locate Yourself**
   - Tap blue location button (bottom right)
   - System predicts your location via WiFi

3. **Search for Destination**
   - Tap search bar at top
   - Type room name
   - Select from autocomplete

4. **Get Directions**
   - Tap "Get Directions" button
   - System calculates shortest path
   - Blue dashed line appears on map

5. **Follow the Path**
   - Zoom in/out as needed
   - Path shows the route
   - Estimated time displayed

---

## Common Issues & Solutions

### Issue: "No graph found for this floor"
**Solution:** Create a graph using the path editor (Step 1)

### Issue: "No path found between locations"
**Solutions:**
- Ensure graph is fully connected
- Check that both locations exist
- Verify locations are on the same floor
- Add more nodes to connect isolated areas

### Issue: "Location not found"
**Solution:** 
- Go to Location Marking screen
- Add the missing location
- Save locations

### Issue: Nodes not appearing in editor
**Solutions:**
- Ensure map image is loaded
- Check browser console for errors
- Verify image size is calculated
- Try refreshing the screen

### Issue: Path looks wrong
**Solutions:**
- Add more nodes for accuracy
- Ensure nodes follow actual walkable paths
- Check that edges are connecting correctly
- Verify coordinate normalization

---

## Performance Tips

### For Best Results
1. **Node Placement**
   - Place nodes every 5-10 meters
   - More nodes = more accurate paths
   - Focus on intersections and turns

2. **Graph Connectivity**
   - Ensure all areas are reachable
   - No isolated node clusters
   - Test paths between distant locations

3. **Location Linking**
   - Place locations near graph nodes
   - System auto-links to nearest node
   - Manual linking for precision

---

## Advanced Testing

### Test Multiple Floors
```bash
# Create graphs for all floors
curl -X POST http://localhost:5000/admin/graph/1 -d '...'
curl -X POST http://localhost:5000/admin/graph/2 -d '...'
curl -X POST http://localhost:5000/admin/graph/3 -d '...'
```

### Test Edge Cases
```bash
# Same location
curl -X POST http://localhost:5000/navigation/path \
  -d '{"floor": 1, "from_location": "Room 101", "to_location": "Room 101"}'

# Non-existent location
curl -X POST http://localhost:5000/navigation/path \
  -d '{"floor": 1, "from_location": "Room 999", "to_location": "Room 101"}'

# Different floors (should fail)
curl -X POST http://localhost:5000/navigation/path \
  -d '{"floor": 1, "from_location": "Room 101", "to_location": "Room 201"}'
```

### Benchmark Performance
```bash
# Time the pathfinding
time curl -X POST http://localhost:5000/navigation/path \
  -d '{"floor": 1, "from_location": "Room 101", "to_location": "Room 202"}'

# Should be < 100ms
```

---

## Next Steps

### Immediate
- [x] Create graph for Floor 1
- [ ] Test pathfinding API
- [ ] Integrate with map screen
- [ ] Test end-to-end navigation

### Short-term
- [ ] Create graphs for Floors 2 & 3
- [ ] Add more nodes for accuracy
- [ ] Link all locations to nodes
- [ ] Test with real users

### Medium-term
- [ ] Add node dragging
- [ ] Add delete functionality
- [ ] Add undo/redo
- [ ] Add node labels

### Long-term
- [ ] Multi-floor navigation
- [ ] Auto-generate graphs
- [ ] Analytics and heatmaps
- [ ] Voice guidance

---

## Success Checklist

- [ ] Graph created for at least one floor
- [ ] Graph saved to MongoDB
- [ ] Pathfinding API returns valid paths
- [ ] Map screen shows calculated routes
- [ ] Users can navigate between locations
- [ ] Performance is acceptable (<100ms)
- [ ] UI is responsive and smooth

---

## Support

**Documentation:**
- `GRAPH_NAVIGATION_SYSTEM.md` - Full technical guide
- `IMPLEMENTATION_COMPLETE.md` - Implementation summary
- `WORKSPACE_ANALYSIS.md` - Project overview

**Need Help?**
- Check backend logs for errors
- Use MongoDB Compass to inspect data
- Test API endpoints with curl
- Check Flutter console for errors

---

**Ready to test!** 🚀

Start with Step 1 and work through each step. The system is fully implemented and ready for use.

# Quick Reference Card

## 🚀 Graph-Based Navigation System

### Start the System

```bash
# Backend
cd backend && python app.py

# Frontend
cd frontend && flutter run
```

---

## 📱 Path Editor Modes

### View Map 🗺️
- See complete navigation system
- Purple pins = locations
- Blue lines = walkable paths
- Hollow circles = nodes

### Edit Paths ✏️

**Add Node** (Teal button)
- Tap map → place node
- Teal circles appear

**Add Edge** (Timeline button)
- Tap first node → turns green
- Tap second node → edge created

**Delete** (Red button)
- Tap node → confirm → deleted
- Tap edge → deleted with undo

**Clear All** (Red button)
- Confirm dialog → all deleted

**Save** (Blue button)
- Saves to MongoDB
- Shows success message

---

## 🎨 Visual Guide

**Node Colors:**
- Teal = Default node
- Green = Selected "from" node
- Orange = Selected node

**Edge Colors:**
- Blue 60% = Normal edge
- Blue 40% = View mode edge

**Location Pins:**
- Purple = Room locations

---

## 🔌 API Endpoints

### Load Graph
```bash
GET /admin/graph/1
```

### Save Graph
```bash
POST /admin/graph/1
Body: {"nodes": [...], "edges": [...]}
```

### Get Path
```bash
POST /navigation/path
Body: {
  "floor": 1,
  "from_location": "Room 101",
  "to_location": "Room 202"
}
```

---

## ⚡ Keyboard Shortcuts (Planned)

- `N` - Add Node mode
- `E` - Add Edge mode
- `D` - Delete mode
- `Esc` - Deselect
- `Ctrl+S` - Save
- `Ctrl+Z` - Undo

---

## 📊 Stats Display

Bottom bar shows:
- 🌳 X nodes
- 📈 Y edges
- 🟠 Unsaved (if changes)

---

## ⚠️ Safety Features

✅ Unsaved changes warning
✅ Delete confirmations
✅ Clear all dialog
✅ Duplicate edge prevention
✅ Undo support

---

## 🎯 Best Practices

**Node Placement:**
- Every 5-10 meters
- At intersections
- Near doorways
- Near room locations

**Edge Creation:**
- Follow actual paths
- No diagonal shortcuts
- Ensure connectivity
- Test long distances

---

## 🐛 Troubleshooting

**Nodes not appearing?**
- Check image loaded
- Verify coordinates normalized
- Check _nodes list

**Can't create edge?**
- Ensure edge mode active
- Check for duplicates
- Verify both nodes exist

**Save failing?**
- Check network connection
- Verify MongoDB running
- Check backend logs

---

## 📚 Documentation

- `GRAPH_NAVIGATION_SYSTEM.md` - Technical
- `PATH_EDITOR_GUIDE.md` - Editor
- `QUICK_START_NAVIGATION.md` - Testing
- `FINAL_SUMMARY.md` - Overview

---

## ✅ Testing Checklist

- [ ] Create graph for Floor 1
- [ ] Add 10+ nodes
- [ ] Connect with edges
- [ ] Save to MongoDB
- [ ] Test pathfinding API
- [ ] Verify in database
- [ ] Test all modes
- [ ] Check visual feedback

---

## 🎉 Success!

You have a production-ready graph-based navigation system!

**Next:** Integrate with map screen for end-to-end navigation.

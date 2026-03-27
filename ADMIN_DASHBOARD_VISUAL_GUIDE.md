# Admin Dashboard Visual Guide

## Color Palette Reference

```
Background Colors:
├── Primary Dark:    #0A1929 (Deep navy - main background)
├── Secondary Dark:  #132F4C (Charcoal - AppBar, panels)
└── Card Overlay:    rgba(255,255,255,0.05) (Glassmorphic cards)

Accent Colors:
├── Electric Blue:   #2979FF (Floor Plan Management)
├── Teal:           #00BCD4 (Location Marking)
├── Purple:         #7C4DFF (Training Data)
├── Orange:         #FF6D00 (Model Retraining)
└── Green:          #00C853 (Statistics & Success)

Text Colors:
├── Primary:        #FFFFFF (White - headings)
├── Secondary:      rgba(255,255,255,0.7) (70% white - body)
├── Tertiary:       rgba(255,255,255,0.4) (40% white - hints)
└── Disabled:       rgba(255,255,255,0.2) (20% white - disabled)
```

## Screen Layouts

### 1. Admin Dashboard (Main Hub)
```
┌─────────────────────────────────────────────────────────────┐
│ [Sidebar]  │  [Top Bar - Admin Dashboard]          [🔔][🏠] │
│            ├──────────────────────────────────────────────────┤
│  [👤]      │                                                  │
│  Admin     │  ┌──────────┐  ┌──────────┐  ┌──────────┐      │
│            │  │   📍     │  │   📌     │  │   📶     │      │
│ ━━━━━━━    │  │  Floor   │  │ Location │  │ Training │      │
│            │  │   Plan   │  │ Marking  │  │   Data   │      │
│ 📊 Dash    │  └──────────┘  └──────────┘  └──────────┘      │
│ ⚙️  Set    │                                                  │
│ ❓ Help    │  ┌──────────┐  ┌──────────┐                     │
│            │  │   🤖     │  │   📊     │                     │
│            │  │  Model   │  │  Stats   │                     │
│ [<>]       │  │ Retrain  │  │Dashboard │                     │
│ [Logout]   │  └──────────┘  └──────────┘                     │
└────────────┴──────────────────────────────────────────────────┘
```

### 2. Floor Plan Screen
```
┌─────────────────────────────────────────────────────────────┐
│ [←] Floor Plan Management                          [🔄]     │
│     Upload and manage floor maps                            │
├─────────────────────────────────────────────────────────────┤
│ [Floor: 1] Floor 1                    [📤 Upload Map]      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                                                             │
│                  [Interactive Map Viewer]                   │
│                  (Zoom, Pan, Scroll)                        │
│                                                             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 3. Location Marking Screen
```
┌─────────────────────────────────────────────────────────────┐
│ [←] Location Marking                               [🔄]     │
│     Mark and edit room positions                            │
├─────────────────────────────────────────────────────────────┤
│ [Floor: 1] [📍 5 Locations]              [💾 Save All]     │
├──────────────────────────────────┬──────────────────────────┤
│                                  │ 📍 Mapped Locations      │
│  [💡 Tap to add location]        ├──────────────────────────┤
│                                  │ 1. Room 101              │
│     [Interactive Map]            │    X: 245  Y: 180        │
│     with Location Markers        │    [✏️] [🗑️]             │
│                                  │                          │
│     📍 Room 101                   │ 2. Lab A                 │
│     📍 Lab A                      │    X: 450  Y: 320        │
│     📍 Corridor                   │    [✏️] [🗑️]             │
│                                  │                          │
│                                  │ 3. Corridor              │
│                                  │    X: 600  Y: 150        │
└──────────────────────────────────┴──────────────────────────┘
```

### 4. Training Data Screen
```
┌─────────────────────────────────────────────────────────────┐
│ [←] Training Data Collection                       [🔄]     │
│     Collect WiFi fingerprints                               │
├─────────────────────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────────────────────┐ │
│ │  📊 Samples: 245  │  📍 Locations: 12  │  📶 BSSIDs: 34 │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ ┌─ Location Details ────────────────────────────────────┐  │
│ │ 📍 Location Name *: [CSE Department Office        ]   │  │
│ │ 📌 Nearby Landmark: [Near HOD Cabin               ]   │  │
│ │ 🏢 Floor:          [Ground Floor                  ]   │  │
│ └───────────────────────────────────────────────────────┘  │
│                                                             │
│ [📶 Scan WiFi Networks]                                     │
│                                                             │
│ ┌─ 15 Networks Found ──────────────── [All] [None] ─────┐  │
│ │ ☑️ 📶 WiFi-Network-1                                   │  │
│ │    AA:BB:CC:DD:EE:FF                                   │  │
│ │    [2400MHz] [-45dBm (78%)] [~5.2m]                    │  │
│ │                                                         │  │
│ │ ☑️ 📶 WiFi-Network-2                                   │  │
│ │    11:22:33:44:55:66                                   │  │
│ │    [5000MHz] [-62dBm (54%)] [~12.8m]                   │  │
│ └─────────────────────────────────────────────────────────┘  │
│                                                             │
│ [☁️ Submit Data & Retrain Model]                           │
└─────────────────────────────────────────────────────────────┘
```

### 5. Model Retraining Screen
```
┌─────────────────────────────────────────────────────────────┐
│ [←] Model Retraining                               [🔄]     │
│     Retrain ML prediction model                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│              ┌─────────────────────────────┐               │
│              │                             │               │
│              │         🤖 (pulsing)        │               │
│              │                             │               │
│              │   Retrain ML Model          │               │
│              │                             │               │
│              │   Retrain the RandomForest  │               │
│              │   model with the latest     │               │
│              │   WiFi fingerprint data...  │               │
│              │                             │               │
│              │  [▶️ Start Retraining]      │               │
│              │                             │               │
│              └─────────────────────────────┘               │
│                                                             │
│  ┌─ Training Dataset Overview ──────────────────────────┐  │
│  │  📊 Total Samples: 245                               │  │
│  │  📍 Unique Locations: 12                             │  │
│  │  📶 WiFi BSSIDs: 34                                  │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌─ How It Works ───────────────────────────────────────┐  │
│  │  • 1. Data Collection                                │  │
│  │  • 2. Feature Engineering                            │  │
│  │  • 3. Model Training                                 │  │
│  │  • 4. Deployment                                     │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 6. Stats Dashboard Screen
```
┌─────────────────────────────────────────────────────────────┐
│ [←] Statistics & Analytics                         [🔄]     │
│     View system metrics                                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                 │
│  │ 📊       │  │ 📍       │  │ 📶       │                 │
│  │   245    │  │    12    │  │    34    │                 │
│  │ Samples  │  │Locations │  │ BSSIDs   │                 │
│  └──────────┘  └──────────┘  └──────────┘                 │
│                                                             │
│  ┌─ System Health ──────────────────────────────────────┐  │
│  │  ✅ Model Status: Trained                            │  │
│  │  📊 Data Quality: Good                               │  │
│  │  🗺️  Coverage: 12 Locations                          │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌─ Data Distribution ──────────────────────────────────┐  │
│  │  📈 Average Samples per Location: 20.4               │  │
│  │  📶 Average BSSIDs per Sample: 2.8                   │  │
│  │  ✅ Data Completeness: 68%                           │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌─ Recommendations ────────────────────────────────────┐  │
│  │  → Collect more training data. Aim for 30-50...     │  │
│  │  → Your dataset looks good! Consider retraining...  │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Component Styles

### Glassmorphic Card
```
┌─────────────────────────────────┐
│ Backdrop Blur: 10px             │
│ Background: rgba(255,255,255,0.05)
│ Border: 1.5px rgba(255,255,255,0.2)
│ Border Radius: 20px             │
│ Shadow: Colored (accent color)  │
│                                 │
│ [Content Here]                  │
│                                 │
└─────────────────────────────────┘
```

### Primary Button
```
┌─────────────────────────────────┐
│  [Icon] Button Text             │
│                                 │
│  Background: Accent Color       │
│  Text: White                    │
│  Border Radius: 16px            │
│  Height: 56px                   │
│  Font: Inter Bold 16px          │
└─────────────────────────────────┘
```

### Input Field
```
┌─────────────────────────────────┐
│ [Icon] Label Text               │
│ ┌─────────────────────────────┐ │
│ │ Input value here...         │ │
│ └─────────────────────────────┘ │
│                                 │
│ Background: rgba(255,255,255,0.05)
│ Border: 1px rgba(255,255,255,0.2)
│ Focus Border: 2px Accent Color  │
│ Border Radius: 14px             │
└─────────────────────────────────┘
```

### Stat Card
```
┌─────────────────┐
│      [Icon]     │
│                 │
│       245       │  ← Outfit Bold 36px
│                 │
│     Samples     │  ← Inter 14px
│                 │
│  WiFi records   │  ← Inter 11px (muted)
└─────────────────┘
```

### Location Marker
```
    📍  ← Icon (32px, colored)
   ┌───┐
   │Lab│ ← Label (white text on colored bg)
   └───┘
```

## Animation Timings

```
Dashboard Card Entrance:
├── Duration: 800ms
├── Curve: easeOutCubic
├── Stagger Delay: 100ms per card
└── Effect: Fade + Slide up (50px)

Sidebar Toggle:
├── Duration: 300ms
├── Curve: easeInOut
└── Effect: Width change (260px ↔ 80px)

Pulse Animation (Retrain):
├── Duration: 1500ms
├── Repeat: Infinite (reverse)
└── Effect: Scale (1.0 ↔ 1.1)

Stats Fade In:
├── Duration: 600ms
├── Curve: easeOutCubic
└── Effect: Opacity (0 → 1)
```

## Responsive Breakpoints

```
Desktop (>1200px):
├── Dashboard: 3 columns
├── Sidebar: Always visible
└── Cards: 400px width

Tablet (800-1200px):
├── Dashboard: 2 columns
├── Sidebar: Collapsible
└── Cards: Flexible width

Mobile (<800px):
├── Dashboard: 1 column
├── Sidebar: Overlay/drawer
└── Cards: Full width
```

## Icon Reference

```
Dashboard Cards:
├── Floor Plan:     map
├── Location:       location_on
├── Training:       wifi
├── Retraining:     model_training
└── Stats:          bar_chart

Navigation:
├── Back:           arrow_back
├── Refresh:        refresh
├── Home:           home_outlined
├── Notifications:  notifications_outlined
└── Settings:       settings

Actions:
├── Upload:         upload_file
├── Save:           save
├── Delete:         delete_outline
├── Edit:           edit_outlined
└── Add:            add_location_alt

Status:
├── Success:        check_circle
├── Error:          error_outline
├── Warning:        warning_outline
├── Info:           info_outline
└── Loading:        CircularProgressIndicator
```

## Typography Scale

```
Headings:
├── H1: Outfit 32px Bold (Dashboard title)
├── H2: Outfit 28px Bold (Page titles)
├── H3: Outfit 24px Bold (Section headers)
├── H4: Outfit 20px Bold (Card titles)
└── H5: Outfit 18px Bold (Subsections)

Body:
├── Large:  Inter 16px Regular (Primary text)
├── Medium: Inter 14px Regular (Secondary text)
├── Small:  Inter 12px Regular (Captions)
└── Tiny:   Inter 11px Regular (Metadata)

Special:
├── Button: Inter 16px Bold
├── Label:  Inter 14px Medium
└── Code:   Roboto Mono 11px Regular
```

## Shadow Styles

```
Card Shadow:
├── Color: Accent color @ 30% opacity
├── Blur: 20px
├── Offset: (0, 10px)
└── Spread: 0

Button Shadow:
├── Color: Black @ 20% opacity
├── Blur: 10px
├── Offset: (0, 4px)
└── Spread: 0

Marker Shadow:
├── Color: Black @ 40% opacity
├── Blur: 8px
├── Offset: (0, 4px)
└── Spread: 0
```

This visual guide provides a complete reference for the admin dashboard design system, making it easy to maintain consistency and extend the interface in the future.

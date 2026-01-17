import json
import sys

def json_to_dart(json_path, dart_path):
    with open(json_path, 'r') as f:
        data = json.load(f)

    dart_content = """import 'dart:ui';

class MapStructure {
  static const double width = %s;
  static const double height = %s;

  static final List<Map<String, dynamic>> walls = [
%s
  ];

  static final List<Map<String, dynamic>> rooms = [
%s
  ];
}
""" % (
        data['width'], 
        data['height'],
        ',\n'.join([f"    {{'x1': {w['x1']}, 'y1': {w['y1']}, 'x2': {w['x2']}, 'y2': {w['y2']}}}" for w in data['walls']]),
        ',\n'.join([f"    {{'id': {r['id']}, 'name': '{r['name']}', 'rect': Rect.fromLTWH({r['rect']['x']}, {r['rect']['y']}, {r['rect']['w']}, {r['rect']['h']})}}" for r in data['rooms']])
    )

    with open(dart_path, 'w') as f:
        f.write(dart_content)
    print(f"Dart code generated at {dart_path}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        pass
    else:
        json_to_dart(sys.argv[1], sys.argv[2])

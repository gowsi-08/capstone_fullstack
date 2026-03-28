import 'package:flutter/material.dart';

/// Represents a node in the walkable graph
/// Coordinates are normalized (0.0 to 1.0) for resolution independence
class GraphNode {
  final String id;
  final double x; // normalized 0.0 to 1.0
  final double y; // normalized 0.0 to 1.0
  final String? label;
  final String? datasetLocation; // Dataset location name from training_data_records

  GraphNode({
    required this.id,
    required this.x,
    required this.y,
    this.label,
    this.datasetLocation,
  });

  /// Create from JSON
  factory GraphNode.fromJson(Map<String, dynamic> json) {
    return GraphNode(
      id: json['id'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      label: json['label'] as String?,
      datasetLocation: json['dataset_location'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'x': x,
      'y': y,
      'label': label ?? '',
      'dataset_location': datasetLocation,
    };
  }

  /// Create a copy with updated fields
  GraphNode copyWith({
    String? id,
    double? x,
    double? y,
    String? label,
    String? datasetLocation,
  }) {
    return GraphNode(
      id: id ?? this.id,
      x: x ?? this.x,
      y: y ?? this.y,
      label: label ?? this.label,
      datasetLocation: datasetLocation ?? this.datasetLocation,
    );
  }

  /// Check if node is mapped to a dataset location
  bool get isMapped => datasetLocation != null && datasetLocation!.isNotEmpty;

  /// Convert normalized coordinates to pixel coordinates
  Offset toPixelOffset(Size imageSize) {
    return Offset(x * imageSize.width, y * imageSize.height);
  }

  /// Create from pixel coordinates
  factory GraphNode.fromPixelOffset({
    required String id,
    required Offset position,
    required Size imageSize,
    String? label,
    String? datasetLocation,
  }) {
    return GraphNode(
      id: id,
      x: position.dx / imageSize.width,
      y: position.dy / imageSize.height,
      label: label,
      datasetLocation: datasetLocation,
    );
  }

  @override
  String toString() => 'GraphNode(id: $id, x: ${x.toStringAsFixed(3)}, y: ${y.toStringAsFixed(3)}, label: $label, datasetLocation: $datasetLocation)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GraphNode && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Represents an edge connecting two nodes in the walkable graph
class GraphEdge {
  final String id;
  final String fromNodeId;
  final String toNodeId;
  final double? weight; // Optional, calculated on backend

  GraphEdge({
    required this.id,
    required this.fromNodeId,
    required this.toNodeId,
    this.weight,
  });

  /// Create from JSON
  factory GraphEdge.fromJson(Map<String, dynamic> json) {
    return GraphEdge(
      id: json['id'] as String,
      fromNodeId: json['from_node'] as String,
      toNodeId: json['to_node'] as String,
      weight: json['weight'] != null ? (json['weight'] as num).toDouble() : null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'from_node': fromNodeId,
      'to_node': toNodeId,
      if (weight != null) 'weight': weight,
    };
  }

  /// Create a copy with updated fields
  GraphEdge copyWith({
    String? id,
    String? fromNodeId,
    String? toNodeId,
    double? weight,
  }) {
    return GraphEdge(
      id: id ?? this.id,
      fromNodeId: fromNodeId ?? this.fromNodeId,
      toNodeId: toNodeId ?? this.toNodeId,
      weight: weight ?? this.weight,
    );
  }

  /// Check if this edge connects to a specific node
  bool connectsTo(String nodeId) {
    return fromNodeId == nodeId || toNodeId == nodeId;
  }

  /// Get the other node ID (given one end)
  String? getOtherNode(String nodeId) {
    if (fromNodeId == nodeId) return toNodeId;
    if (toNodeId == nodeId) return fromNodeId;
    return null;
  }

  @override
  String toString() => 'GraphEdge(id: $id, from: $fromNodeId, to: $toNodeId, weight: ${weight?.toStringAsFixed(3)})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GraphEdge && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Represents a complete walkable graph for a floor
class WalkableGraph {
  final int floor;
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final DateTime? updatedAt;

  WalkableGraph({
    required this.floor,
    required this.nodes,
    required this.edges,
    this.updatedAt,
  });

  /// Create from JSON
  factory WalkableGraph.fromJson(Map<String, dynamic> json) {
    return WalkableGraph(
      floor: json['floor'] as int,
      nodes: (json['nodes'] as List<dynamic>)
          .map((n) => GraphNode.fromJson(n as Map<String, dynamic>))
          .toList(),
      edges: (json['edges'] as List<dynamic>)
          .map((e) => GraphEdge.fromJson(e as Map<String, dynamic>))
          .toList(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'floor': floor,
      'nodes': nodes.map((n) => n.toJson()).toList(),
      'edges': edges.map((e) => e.toJson()).toList(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  /// Check if graph is empty
  bool get isEmpty => nodes.isEmpty && edges.isEmpty;

  /// Check if graph has content
  bool get isNotEmpty => !isEmpty;

  /// Get node by ID
  GraphNode? getNode(String nodeId) {
    try {
      return nodes.firstWhere((n) => n.id == nodeId);
    } catch (e) {
      return null;
    }
  }

  /// Get all edges connected to a node
  List<GraphEdge> getEdgesForNode(String nodeId) {
    return edges.where((e) => e.connectsTo(nodeId)).toList();
  }

  /// Get neighboring nodes for a given node
  List<GraphNode> getNeighbors(String nodeId) {
    final connectedEdges = getEdgesForNode(nodeId);
    final neighborIds = connectedEdges
        .map((e) => e.getOtherNode(nodeId))
        .where((id) => id != null)
        .cast<String>()
        .toList();
    return neighborIds.map((id) => getNode(id)).whereType<GraphNode>().toList();
  }

  @override
  String toString() => 'WalkableGraph(floor: $floor, nodes: ${nodes.length}, edges: ${edges.length})';
}

/// Represents a calculated navigation path
class NavigationPath {
  final List<Offset> points; // normalized coordinates (0.0 to 1.0)
  final double totalDistance;
  final int estimatedSeconds;
  final bool found;
  final String? message;

  NavigationPath({
    required this.points,
    required this.totalDistance,
    required this.estimatedSeconds,
    required this.found,
    this.message,
  });

  /// Create from API response
  factory NavigationPath.fromJson(Map<String, dynamic> json) {
    final pathNodes = json['path_nodes'] as List<dynamic>? ?? [];
    final points = pathNodes
        .map((node) => Offset(
              (node['x'] as num).toDouble(),
              (node['y'] as num).toDouble(),
            ))
        .toList();

    return NavigationPath(
      points: points,
      totalDistance: (json['total_distance'] as num?)?.toDouble() ?? 0.0,
      estimatedSeconds: json['estimated_seconds'] as int? ?? 0,
      found: json['found'] as bool? ?? false,
      message: json['message'] as String?,
    );
  }

  /// Convert normalized coordinates to pixel coordinates
  List<Offset> toPixelCoordinates(Size imageSize) {
    return points
        .map((p) => Offset(p.dx * imageSize.width, p.dy * imageSize.height))
        .toList();
  }

  /// Get estimated time in minutes
  int get estimatedMinutes => (estimatedSeconds / 60).ceil();

  /// Check if path is empty
  bool get isEmpty => points.isEmpty;

  /// Check if path has content
  bool get isNotEmpty => !isEmpty;

  /// Get number of waypoints
  int get waypointCount => points.length;

  @override
  String toString() =>
      'NavigationPath(found: $found, points: ${points.length}, distance: ${totalDistance.toStringAsFixed(3)}, time: ${estimatedSeconds}s)';
}

/// Represents a location marker on the map
class LocationMarker {
  final String id;
  final String name;
  final String? landmark;
  final int floor;
  final double x; // normalized 0.0 to 1.0
  final double y; // normalized 0.0 to 1.0
  final String? nodeId; // linked graph node

  LocationMarker({
    required this.id,
    required this.name,
    this.landmark,
    required this.floor,
    required this.x,
    required this.y,
    this.nodeId,
  });

  /// Create from JSON
  factory LocationMarker.fromJson(Map<String, dynamic> json) {
    return LocationMarker(
      id: json['id'] as String,
      name: json['name'] as String,
      landmark: json['landmark'] as String?,
      floor: json['floor'] as int,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      nodeId: json['node_id'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (landmark != null) 'landmark': landmark,
      'floor': floor,
      'x': x,
      'y': y,
      if (nodeId != null) 'node_id': nodeId,
    };
  }

  /// Create a copy with updated fields
  LocationMarker copyWith({
    String? id,
    String? name,
    String? landmark,
    int? floor,
    double? x,
    double? y,
    String? nodeId,
  }) {
    return LocationMarker(
      id: id ?? this.id,
      name: name ?? this.name,
      landmark: landmark ?? this.landmark,
      floor: floor ?? this.floor,
      x: x ?? this.x,
      y: y ?? this.y,
      nodeId: nodeId ?? this.nodeId,
    );
  }

  /// Convert normalized coordinates to pixel coordinates
  Offset toPixelOffset(Size imageSize) {
    return Offset(x * imageSize.width, y * imageSize.height);
  }

  /// Create from pixel coordinates
  factory LocationMarker.fromPixelOffset({
    required String id,
    required String name,
    String? landmark,
    required int floor,
    required Offset position,
    required Size imageSize,
    String? nodeId,
  }) {
    return LocationMarker(
      id: id,
      name: name,
      landmark: landmark,
      floor: floor,
      x: position.dx / imageSize.width,
      y: position.dy / imageSize.height,
      nodeId: nodeId,
    );
  }

  /// Check if location is linked to a graph node
  bool get isLinked => nodeId != null && nodeId!.isNotEmpty;

  /// Get display text
  String get displayText => landmark != null && landmark!.isNotEmpty
      ? '$name ($landmark)'
      : name;

  @override
  String toString() =>
      'LocationMarker(id: $id, name: $name, floor: $floor, x: ${x.toStringAsFixed(3)}, y: ${y.toStringAsFixed(3)}, linked: $isLinked)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationMarker &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Represents a navigable location (node with dataset_location assigned)
class NavigableLocation {
  final String locationName;
  final String nodeId;
  final double x; // normalized 0.0 to 1.0
  final double y; // normalized 0.0 to 1.0
  final int floor;
  final int recordCount;

  NavigableLocation({
    required this.locationName,
    required this.nodeId,
    required this.x,
    required this.y,
    required this.floor,
    required this.recordCount,
  });

  /// Create from JSON
  factory NavigableLocation.fromJson(Map<String, dynamic> json) {
    return NavigableLocation(
      locationName: json['location_name'] as String,
      nodeId: json['node_id'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      floor: json['floor'] as int,
      recordCount: json['record_count'] as int? ?? 0,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'location_name': locationName,
      'node_id': nodeId,
      'x': x,
      'y': y,
      'floor': floor,
      'record_count': recordCount,
    };
  }

  /// Convert normalized coordinates to pixel coordinates
  Offset toPixelOffset(Size imageSize) {
    return Offset(x * imageSize.width, y * imageSize.height);
  }

  /// Get display text with record count
  String get displayText => '$locationName ($recordCount records)';

  @override
  String toString() =>
      'NavigableLocation(name: $locationName, floor: $floor, node: $nodeId, records: $recordCount)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NavigableLocation &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId;

  @override
  int get hashCode => nodeId.hashCode;
}

/// Helper class for coordinate conversion
class CoordinateConverter {
  /// Convert normalized (0-1) to pixel coordinates
  static Offset normalizedToPixel(double x, double y, Size imageSize) {
    return Offset(x * imageSize.width, y * imageSize.height);
  }

  /// Convert pixel to normalized (0-1) coordinates
  static Offset pixelToNormalized(Offset position, Size imageSize) {
    return Offset(
      position.dx / imageSize.width,
      position.dy / imageSize.height,
    );
  }

  /// Convert list of normalized coordinates to pixel coordinates
  static List<Offset> normalizedListToPixel(
      List<Offset> points, Size imageSize) {
    return points
        .map((p) => normalizedToPixel(p.dx, p.dy, imageSize))
        .toList();
  }

  /// Convert list of pixel coordinates to normalized coordinates
  static List<Offset> pixelListToNormalized(
      List<Offset> points, Size imageSize) {
    return points.map((p) => pixelToNormalized(p, imageSize)).toList();
  }

  /// Clamp coordinates to valid range (0-1)
  static Offset clampNormalized(Offset position) {
    return Offset(
      position.dx.clamp(0.0, 1.0),
      position.dy.clamp(0.0, 1.0),
    );
  }
}

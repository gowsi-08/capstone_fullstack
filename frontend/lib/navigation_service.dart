import 'dart:collection';
import 'dart:math';
import 'package:flutter/material.dart';

class Node {
  final String id;
  final Offset position;

  Node(this.id, this.position);

  @override
  bool operator ==(Object other) => other is Node && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class Edge {
  final Node to;
  final double weight;

  Edge(this.to, this.weight);
}

class NavigationService {
  final Map<Node, List<Edge>> _graph = {};

  void addNode(Node node) {
    _graph.putIfAbsent(node, () => []);
  }

  void addEdge(Node node1, Node node2) {
    double distance = sqrt(pow(node1.position.dx - node2.position.dx, 2) +
        pow(node1.position.dy - node2.position.dy, 2));
    _graph[node1]?.add(Edge(node2, distance));
    _graph[node2]?.add(Edge(node1, distance));
  }

  /// NEW DYNAMIC PATH FORMATION LOGIC
  /// This creates a "Central Spine" hallway based on the bounding box of all rooms
  /// and connects every room to that spine. This ensures 100% connectivity.
  void initGraph(Map<String, Offset> roomPositions) {
    _graph.clear();
    if (roomPositions.isEmpty) return;

    // 1. Calculate Bounding Box and Center Line
    double minX = double.infinity, maxX = -double.infinity;
    double minY = double.infinity, maxY = -double.infinity;

    roomPositions.forEach((name, pos) {
      if (pos.dx < minX) minX = pos.dx;
      if (pos.dx > maxX) maxX = pos.dx;
      if (pos.dy < minY) minY = pos.dy;
      if (pos.dy > maxY) maxY = pos.dy;
      addNode(Node(name, pos));
    });

    // 2. Determine building orientation (Vertical or Horizontal)
    bool isVertical = (maxY - minY) > (maxX - minX);
    double centerX = (minX + maxX) / 2;
    double centerY = (minY + maxY) / 2;

    // 3. Create a Dynamic "Hallway Spine"
    // We create nodes every 100 pixels along the longer axis
    final List<Node> spineNodes = [];
    if (isVertical) {
      for (double y = minY; y <= maxY; y += 100) {
        final node = Node('SPINE_$y', Offset(centerX, y));
        addNode(node);
        spineNodes.add(node);
      }
    } else {
      for (double x = minX; x <= maxX; x += 100) {
        final node = Node('SPINE_$x', Offset(x, centerY));
        addNode(node);
        spineNodes.add(node);
      }
    }

    // 4. Connect Spine Nodes in a Chain
    for (int i = 0; i < spineNodes.length - 1; i++) {
      addEdge(spineNodes[i], spineNodes[i + 1]);
    }

    // 5. Connect Every Room to the NEAREST Spine Node
    roomPositions.forEach((name, pos) {
      final roomNode = _findNodeById(name);
      if (roomNode != null) {
        Node? nearestSpine;
        double minDist = double.infinity;
        for (var sNode in spineNodes) {
          double d = sqrt(pow(pos.dx - sNode.position.dx, 2) + pow(pos.dy - sNode.position.dy, 2));
          if (d < minDist) {
            minDist = d;
            nearestSpine = sNode;
          }
        }
        if (nearestSpine != null) {
          addEdge(roomNode, nearestSpine);
        }
      }
    });
  }

  Node? _findNodeById(String id) {
    for (var node in _graph.keys) {
      if (node.id == id) return node;
    }
    return null;
  }

  List<Offset> findShortestPath(String startId, String endId) {
    if (startId == endId || startId.isEmpty || endId.isEmpty) return [];

    Node? startNode = _findNodeById(startId);
    Node? endNode = _findNodeById(endId);

    if (startNode == null || endNode == null) return [];

    final distances = <Node, double>{};
    final previous = <Node, Node?>{};
    final queue = SplayTreeSet<Node>((a, b) {
      final da = distances[a] ?? double.infinity;
      final db = distances[b] ?? double.infinity;
      if (da == db) return a.id.compareTo(b.id);
      return da.compareTo(db);
    });

    for (var node in _graph.keys) {
      distances[node] = double.infinity;
      previous[node] = null;
    }

    distances[startNode] = 0;
    queue.add(startNode);

    while (queue.isNotEmpty) {
      final current = queue.first;
      queue.remove(current);

      if (current == endNode) break;

      final neighbors = _graph[current];
      if (neighbors == null) continue;

      for (var edge in neighbors) {
        final neighbor = edge.to;
        final alt = distances[current]! + edge.weight;
        if (alt < distances[neighbor]!) {
          queue.remove(neighbor);
          distances[neighbor] = alt;
          previous[neighbor] = current;
          queue.add(neighbor);
        }
      }
    }

    final path = <Offset>[];
    Node? temp = endNode;
    while (temp != null) {
      path.insert(0, temp.position);
      temp = previous[temp];
    }

    return path.length > 1 ? path : [];
  }
}

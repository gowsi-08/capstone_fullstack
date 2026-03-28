"""
Pathfinding Service - Graph-based navigation using Dijkstra's algorithm
"""
import heapq
import math
from typing import Dict, List, Tuple, Optional
from services.database import db


class PathfindingService:
    """Service for graph-based pathfinding on floor maps"""
    
    def __init__(self):
        self.graphs_cache = {}  # Cache loaded graphs by floor
    
    def build_graph(self, floor: int) -> Optional[Dict]:
        """
        Load graph from MongoDB and build adjacency structure
        Returns: {
            'nodes': {node_id: {'x': float, 'y': float, 'label': str}},
            'adjacency': {node_id: [(neighbor_id, weight), ...]},
            'raw': original document
        }
        """
        try:
            graph_doc = db.walkable_graph.find_one({'floor': floor})
            if not graph_doc:
                return None
            
            nodes = {}
            adjacency = {}
            
            # Build nodes dict
            for node in graph_doc.get('nodes', []):
                node_id = node['id']
                nodes[node_id] = {
                    'x': node['x'],
                    'y': node['y'],
                    'label': node.get('label', '')
                }
                adjacency[node_id] = []
            
            # Build adjacency list with weights
            for edge in graph_doc.get('edges', []):
                from_node = edge['from_node']
                to_node = edge['to_node']
                weight = edge.get('weight', 1.0)
                
                # Bidirectional edges
                if from_node in adjacency:
                    adjacency[from_node].append((to_node, weight))
                if to_node in adjacency:
                    adjacency[to_node].append((from_node, weight))
            
            return {
                'nodes': nodes,
                'adjacency': adjacency,
                'raw': graph_doc
            }
        except Exception as e:
            print(f"Error building graph for floor {floor}: {e}")
            return None
    
    def calculate_distance(self, x1: float, y1: float, x2: float, y2: float) -> float:
        """Calculate Euclidean distance between two normalized coordinates"""
        return math.sqrt((x2 - x1) ** 2 + (y2 - y1) ** 2)
    
    def find_nearest_node(self, nodes: Dict, x: float, y: float) -> Optional[str]:
        """Find the closest node to given coordinates"""
        if not nodes:
            return None
        
        min_dist = float('inf')
        nearest_id = None
        
        for node_id, node_data in nodes.items():
            dist = self.calculate_distance(x, y, node_data['x'], node_data['y'])
            if dist < min_dist:
                min_dist = dist
                nearest_id = node_id
        
        return nearest_id
    
    def dijkstra(self, adjacency: Dict, start_node: str, end_node: str) -> Optional[List[str]]:
        """
        Dijkstra's shortest path algorithm
        Returns: List of node IDs from start to end, or None if no path exists
        """
        if start_node not in adjacency or end_node not in adjacency:
            return None
        
        # Priority queue: (distance, node_id)
        pq = [(0, start_node)]
        distances = {start_node: 0}
        previous = {start_node: None}
        visited = set()
        
        while pq:
            current_dist, current_node = heapq.heappop(pq)
            
            if current_node in visited:
                continue
            
            visited.add(current_node)
            
            # Found destination
            if current_node == end_node:
                break
            
            # Check neighbors
            for neighbor, weight in adjacency.get(current_node, []):
                if neighbor in visited:
                    continue
                
                new_dist = current_dist + weight
                
                if neighbor not in distances or new_dist < distances[neighbor]:
                    distances[neighbor] = new_dist
                    previous[neighbor] = current_node
                    heapq.heappush(pq, (new_dist, neighbor))
        
        # Reconstruct path
        if end_node not in previous and end_node != start_node:
            return None  # No path found
        
        path = []
        current = end_node
        while current is not None:
            path.append(current)
            current = previous.get(current)
        
        path.reverse()
        return path
    
    def calculate_path(self, floor: int, from_location: str, to_location: str) -> Dict:
        """
        Calculate shortest path between two locations
        Returns: {
            'path_nodes': [{'x': float, 'y': float}, ...],
            'total_distance': float,
            'estimated_seconds': int,
            'found': bool
        }
        """
        try:
            # Load graph
            graph = self.build_graph(floor)
            if not graph:
                return {
                    'path_nodes': [],
                    'total_distance': 0,
                    'estimated_seconds': 0,
                    'found': False,
                    'error': 'No walkable graph found for this floor'
                }
            
            nodes = graph['nodes']
            adjacency = graph['adjacency']
            
            # Get location coordinates
            from_loc = db.locations.find_one({'floor': str(floor), 'name': from_location})
            to_loc = db.locations.find_one({'floor': str(floor), 'name': to_location})
            
            if not from_loc or not to_loc:
                return {
                    'path_nodes': [],
                    'total_distance': 0,
                    'estimated_seconds': 0,
                    'found': False,
                    'error': 'Location not found'
                }
            
            # Find start and end nodes
            # Use node_id if set, otherwise find nearest node
            if from_loc.get('node_id') and from_loc['node_id'] in nodes:
                start_node = from_loc['node_id']
            else:
                # Normalize coordinates (assuming locations store pixel coords)
                # We'll need map dimensions - for now use direct lookup
                start_node = self.find_nearest_node(nodes, from_loc['x'], from_loc['y'])
            
            if to_loc.get('node_id') and to_loc['node_id'] in nodes:
                end_node = to_loc['node_id']
            else:
                end_node = self.find_nearest_node(nodes, to_loc['x'], to_loc['y'])
            
            if not start_node or not end_node:
                return {
                    'path_nodes': [],
                    'total_distance': 0,
                    'estimated_seconds': 0,
                    'found': False,
                    'error': 'Could not find nodes near locations'
                }
            
            # Run Dijkstra
            path_node_ids = self.dijkstra(adjacency, start_node, end_node)
            
            if not path_node_ids:
                return {
                    'path_nodes': [],
                    'total_distance': 0,
                    'estimated_seconds': 0,
                    'found': False,
                    'error': 'No path found between locations'
                }
            
            # Convert node IDs to coordinates
            path_coords = []
            total_distance = 0
            
            for i, node_id in enumerate(path_node_ids):
                node = nodes[node_id]
                path_coords.append({'x': node['x'], 'y': node['y']})
                
                # Calculate cumulative distance
                if i > 0:
                    prev_node = nodes[path_node_ids[i-1]]
                    total_distance += self.calculate_distance(
                        prev_node['x'], prev_node['y'],
                        node['x'], node['y']
                    )
            
            # Estimate time (assuming average walking speed of 1.4 m/s)
            # Normalized distance * map scale factor (assume 1000 pixels = 50m)
            estimated_meters = total_distance * 50  # Rough estimate
            estimated_seconds = int(estimated_meters / 1.4)
            
            return {
                'path_nodes': path_coords,
                'total_distance': round(total_distance, 4),
                'estimated_seconds': estimated_seconds,
                'found': True
            }
            
        except Exception as e:
            print(f"Error calculating path: {e}")
            return {
                'path_nodes': [],
                'total_distance': 0,
                'estimated_seconds': 0,
                'found': False,
                'error': str(e)
            }
    
    def save_graph(self, floor: int, nodes: List[Dict], edges: List[Dict]) -> bool:
        """Save or update walkable graph for a floor"""
        try:
            from datetime import datetime
            
            # Calculate weights for edges based on node positions
            for edge in edges:
                from_node_data = next((n for n in nodes if n['id'] == edge['from_node']), None)
                to_node_data = next((n for n in nodes if n['id'] == edge['to_node']), None)
                
                if from_node_data and to_node_data:
                    edge['weight'] = self.calculate_distance(
                        from_node_data['x'], from_node_data['y'],
                        to_node_data['x'], to_node_data['y']
                    )
                else:
                    edge['weight'] = 1.0
            
            graph_doc = {
                'floor': floor,
                'nodes': nodes,
                'edges': edges,
                'updated_at': datetime.utcnow()
            }
            
            db.walkable_graph.update_one(
                {'floor': floor},
                {'$set': graph_doc},
                upsert=True
            )
            
            # Clear cache
            if floor in self.graphs_cache:
                del self.graphs_cache[floor]
            
            return True
        except Exception as e:
            print(f"Error saving graph: {e}")
            return False
    
    def delete_graph(self, floor: int) -> bool:
        """Delete walkable graph for a floor"""
        try:
            db.walkable_graph.delete_one({'floor': floor})
            if floor in self.graphs_cache:
                del self.graphs_cache[floor]
            return True
        except Exception as e:
            print(f"Error deleting graph: {e}")
            return False


# Singleton instance
pathfinding_service = PathfindingService()

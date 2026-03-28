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
            'nodes': {node_id: {'x': float, 'y': float, 'label': str, 'dataset_location': str}},
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
                    'label': node.get('label', ''),
                    'dataset_location': node.get('dataset_location', None)
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
    
    def find_node_by_dataset_location(self, nodes: Dict, dataset_location: str) -> Optional[str]:
        """Find node ID that has the given dataset_location assigned"""
        for node_id, node_data in nodes.items():
            if node_data.get('dataset_location') == dataset_location:
                return node_id
        return None
    
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
        Calculate shortest path between two dataset locations
        Args:
            floor: Floor number
            from_location: Dataset location name (from training_data_records)
            to_location: Dataset location name (from training_data_records)
        Returns: {
            'path_nodes': [{'x': float, 'y': float}, ...],
            'total_distance': float,
            'estimated_seconds': int,
            'found': bool,
            'reason': str (if not found)
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
                    'reason': 'no_graph',
                    'error': 'No walkable graph found for this floor'
                }
            
            nodes = graph['nodes']
            adjacency = graph['adjacency']
            
            # Find nodes by dataset_location
            start_node = self.find_node_by_dataset_location(nodes, from_location)
            end_node = self.find_node_by_dataset_location(nodes, to_location)
            
            if not start_node:
                return {
                    'path_nodes': [],
                    'total_distance': 0,
                    'estimated_seconds': 0,
                    'found': False,
                    'reason': 'location_not_mapped',
                    'error': f'Start location "{from_location}" is not mapped to any graph node'
                }
            
            if not end_node:
                return {
                    'path_nodes': [],
                    'total_distance': 0,
                    'estimated_seconds': 0,
                    'found': False,
                    'reason': 'location_not_mapped',
                    'error': f'Destination "{to_location}" is not mapped to any graph node'
                }
            
            # Run Dijkstra
            path_node_ids = self.dijkstra(adjacency, start_node, end_node)
            
            if not path_node_ids:
                return {
                    'path_nodes': [],
                    'total_distance': 0,
                    'estimated_seconds': 0,
                    'found': False,
                    'reason': 'no_path',
                    'error': 'No walkable path found between locations'
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
                'reason': 'error',
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
    
    def get_dataset_locations(self, floor: int) -> List[Dict]:
        """
        Get all distinct dataset locations for a floor with assignment status
        Returns: [{
            'location': str,
            'floor': int,
            'record_count': int,
            'assigned_node_id': str or None,
            'is_assigned': bool
        }]
        """
        try:
            # Get distinct locations from training_data_records
            pipeline = [
                {'$match': {'floor': floor}},
                {'$group': {
                    '_id': '$location',
                    'count': {'$sum': 1}
                }},
                {'$sort': {'_id': 1}}
            ]
            
            locations = list(db.training_data_records.aggregate(pipeline))
            
            # Get graph to check assignments
            graph = self.build_graph(floor)
            location_to_node = {}
            
            if graph:
                for node_id, node_data in graph['nodes'].items():
                    dataset_loc = node_data.get('dataset_location')
                    if dataset_loc:
                        location_to_node[dataset_loc] = node_id
            
            # Build result
            result = []
            for loc in locations:
                location_name = loc['_id']
                assigned_node_id = location_to_node.get(location_name)
                
                result.append({
                    'location': location_name,
                    'floor': floor,
                    'record_count': loc['count'],
                    'assigned_node_id': assigned_node_id,
                    'is_assigned': assigned_node_id is not None
                })
            
            return result
            
        except Exception as e:
            print(f"Error getting dataset locations: {e}")
            return []
    
    def assign_dataset_location(self, floor: int, node_id: str, dataset_location: str) -> Dict:
        """
        Assign a dataset location to a node
        Ensures uniqueness: only one node per floor can have a given dataset_location
        Returns: {
            'success': bool,
            'message': str,
            'previous_node_id': str or None
        }
        """
        try:
            # Check if another node already has this dataset_location
            graph_doc = db.walkable_graph.find_one({'floor': floor})
            if not graph_doc:
                return {
                    'success': False,
                    'message': 'No graph found for this floor',
                    'previous_node_id': None
                }
            
            previous_node_id = None
            nodes = graph_doc.get('nodes', [])
            
            # Find and unassign previous node with this dataset_location
            for node in nodes:
                if node.get('dataset_location') == dataset_location and node['id'] != node_id:
                    previous_node_id = node['id']
                    node['dataset_location'] = None
                    break
            
            # Assign to target node
            target_node_found = False
            for node in nodes:
                if node['id'] == node_id:
                    node['dataset_location'] = dataset_location
                    target_node_found = True
                    break
            
            if not target_node_found:
                return {
                    'success': False,
                    'message': f'Node {node_id} not found in graph',
                    'previous_node_id': None
                }
            
            # Save updated graph
            db.walkable_graph.update_one(
                {'floor': floor},
                {'$set': {'nodes': nodes}}
            )
            
            # Clear cache
            if floor in self.graphs_cache:
                del self.graphs_cache[floor]
            
            message = f'Assigned "{dataset_location}" to node {node_id}'
            if previous_node_id:
                message += f' (unassigned from {previous_node_id})'
            
            return {
                'success': True,
                'message': message,
                'previous_node_id': previous_node_id
            }
            
        except Exception as e:
            print(f"Error assigning dataset location: {e}")
            return {
                'success': False,
                'message': str(e),
                'previous_node_id': None
            }
    
    def unassign_dataset_location(self, floor: int, node_id: str) -> Dict:
        """
        Remove dataset_location assignment from a node
        Returns: {'success': bool, 'message': str}
        """
        try:
            graph_doc = db.walkable_graph.find_one({'floor': floor})
            if not graph_doc:
                return {
                    'success': False,
                    'message': 'No graph found for this floor'
                }
            
            nodes = graph_doc.get('nodes', [])
            node_found = False
            
            for node in nodes:
                if node['id'] == node_id:
                    node['dataset_location'] = None
                    node_found = True
                    break
            
            if not node_found:
                return {
                    'success': False,
                    'message': f'Node {node_id} not found in graph'
                }
            
            # Save updated graph
            db.walkable_graph.update_one(
                {'floor': floor},
                {'$set': {'nodes': nodes}}
            )
            
            # Clear cache
            if floor in self.graphs_cache:
                del self.graphs_cache[floor]
            
            return {
                'success': True,
                'message': f'Unassigned dataset location from node {node_id}'
            }
            
        except Exception as e:
            print(f"Error unassigning dataset location: {e}")
            return {
                'success': False,
                'message': str(e)
            }
    
    def get_navigable_locations(self, floor: Optional[int] = None) -> List[Dict]:
        """
        Get only nodes that have dataset_location assigned (navigable destinations)
        Args:
            floor: Specific floor number, or None for all floors
        Returns: [{
            'location_name': str,
            'node_id': str,
            'x': float,
            'y': float,
            'floor': int,
            'record_count': int
        }]
        """
        try:
            result = []
            
            # Determine which floors to query
            if floor is not None:
                floors = [floor]
            else:
                # Get all floors that have graphs
                graph_docs = db.walkable_graph.find({}, {'floor': 1})
                floors = [doc['floor'] for doc in graph_docs]
            
            for floor_num in floors:
                graph = self.build_graph(floor_num)
                if not graph:
                    continue
                
                # Get record counts for this floor
                pipeline = [
                    {'$match': {'floor': floor_num}},
                    {'$group': {
                        '_id': '$location',
                        'count': {'$sum': 1}
                    }}
                ]
                location_counts = {
                    item['_id']: item['count']
                    for item in db.training_data_records.aggregate(pipeline)
                }
                
                # Find nodes with dataset_location assigned
                for node_id, node_data in graph['nodes'].items():
                    dataset_loc = node_data.get('dataset_location')
                    if dataset_loc:
                        result.append({
                            'location_name': dataset_loc,
                            'node_id': node_id,
                            'x': node_data['x'],
                            'y': node_data['y'],
                            'floor': floor_num,
                            'record_count': location_counts.get(dataset_loc, 0)
                        })
            
            # Sort by floor then location name
            result.sort(key=lambda x: (x['floor'], x['location_name']))
            
            return result
            
        except Exception as e:
            print(f"Error getting navigable locations: {e}")
            return []


# Singleton instance
pathfinding_service = PathfindingService()

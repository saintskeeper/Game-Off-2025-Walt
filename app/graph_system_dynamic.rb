# Dynamic Graph System - Generates paths using navigation grid
#
# Core Concepts:
# - Define key waypoint locations (ports, islands)
# - Use pathfinding to generate valid paths between waypoints
# - Dynamically create edge slots based on path length
# - Ensure all paths follow accessible ocean routes

# Load pathfinding system (DragonRuby or standard Ruby)
begin
  require 'app/pathfinding_system.rb'
rescue LoadError
  require_relative 'pathfinding_system.rb'
end

# Define key waypoint locations (these will be validated/adjusted to accessible positions)
# These are the important story/gameplay locations
KEY_WAYPOINTS = {
  start: {
    id: :start,
    desired_position: { x: 200, y: 360 },  # Will be adjusted to nearest accessible cell
    type: :port,
    metadata: { name: "Home Port" }
  },
  treasure_isle: {
    id: :treasure_isle,
    desired_position: { x: 800, y: 360 },
    type: :port,
    metadata: { name: "Treasure Isle" }
  },
  north_island: {
    id: :north_island,
    desired_position: { x: 500, y: 500 },
    type: :island,
    metadata: { name: "North Island" }
  },
  south_island: {
    id: :south_island,
    desired_position: { x: 500, y: 220 },
    type: :island,
    metadata: { name: "South Island" }
  }
}

# Find nearest accessible grid cell to a desired position
# Args:
#   desired_x, desired_y - Desired screen coordinates
#   max_search_radius - Maximum distance to search (in grid cells)
# Returns:
#   Hash with :x and :y screen coordinates of nearest accessible cell, or nil
def find_nearest_accessible_position(desired_x, desired_y, max_search_radius = 10)
  grid_pos = screen_to_grid(desired_x, desired_y)

  # If the desired position is already accessible, use it
  if grid_cell_accessible?(grid_pos[:x], grid_pos[:y])
    return { x: desired_x, y: desired_y }
  end

  # Search in expanding radius
  (1..max_search_radius).each do |radius|
    (-radius..radius).each do |dy|
      (-radius..radius).each do |dx|
        # Skip if not on the perimeter of current radius
        next unless dx.abs == radius || dy.abs == radius

        check_x = grid_pos[:x] + dx
        check_y = grid_pos[:y] + dy

        if grid_cell_accessible?(check_x, check_y)
          return grid_to_screen(check_x, check_y)
        end
      end
    end
  end

  # No accessible position found nearby
  nil
end

# Initialize waypoint nodes with validated positions
# Returns:
#   Hash of node_id => node_data with accessible positions
def initialize_waypoint_nodes
  nodes = {}

  KEY_WAYPOINTS.each do |id, waypoint_def|
    desired = waypoint_def[:desired_position]
    accessible_pos = find_nearest_accessible_position(desired[:x], desired[:y])

    if accessible_pos
      nodes[id] = {
        id: id,
        position: accessible_pos,
        type: waypoint_def[:type],
        metadata: waypoint_def[:metadata]
      }
    else
      puts "WARNING: Could not find accessible position for waypoint #{id}"
    end
  end

  nodes
end

# Generate edges between nodes using pathfinding
# Args:
#   nodes - Hash of node data
#   connections - Array of [from_id, to_id] pairs defining which nodes to connect
# Returns:
#   Array of edge hashes with paths and tile slots
def generate_edges(nodes, connections)
  edges = []

  connections.each do |from_id, to_id|
    from_node = nodes[from_id]
    to_node = nodes[to_id]

    next unless from_node && to_node

    # Find path between nodes
    path = find_path(
      from_node[:position][:x], from_node[:position][:y],
      to_node[:position][:x], to_node[:position][:y]
    )

    if path
      # Create edge with slots based on path length
      # Each path segment becomes a slot
      slots = [path.length - 1, 3].max  # Minimum 3 slots

      edge = {
        id: "#{from_id}_to_#{to_id}".to_sym,
        from: from_id,
        to: to_id,
        slots: slots,
        tiles: Array.new(slots),
        path: path  # Store the full path for rendering
      }

      edges << edge
    else
      puts "WARNING: Could not find path from #{from_id} to #{to_id}"
    end
  end

  edges
end

# Build dynamic graph with pathfinding
# Returns:
#   Hash with nodes, edges, and metadata
def build_dynamic_graph
  # Initialize waypoint nodes at accessible positions
  nodes = initialize_waypoint_nodes

  # Define connections (gameplay route)
  # This creates a loop: start -> north -> treasure -> south -> start
  connections = [
    [:start, :north_island],
    [:north_island, :treasure_isle],
    [:treasure_isle, :south_island],
    [:south_island, :start]
  ]

  # Generate edges with pathfinding
  edges = generate_edges(nodes, connections)

  {
    nodes: nodes,
    edges: edges,
    start_node: :start
  }
end

# Helper to get edge position at a specific progress point
# Interpolates along the pathfound route
# Args:
#   edge - Edge hash with :path array
#   progress - Current slot index
# Returns:
#   Hash with :x and :y screen coordinates
def get_edge_path_position(edge, progress)
  return edge[:path][0] if edge[:path].empty? || progress <= 0
  return edge[:path][-1] if progress >= edge[:slots]

  # Interpolate along the path
  path_index = ((progress.to_f / edge[:slots]) * (edge[:path].length - 1)).floor
  path_index = [[path_index, 0].max, edge[:path].length - 1].min

  edge[:path][path_index]
end

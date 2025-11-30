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
# Journey: Caribbean (left) -> Mid-Atlantic -> European Port (right)
KEY_WAYPOINTS = {
  caribbean_port: {
    id: :caribbean_port,
    desired_position: { x: 200, y: 360 },  # Left side - Caribbean starting point
    type: :port,
    metadata: { name: "Caribbean Port" }
  },
  mid_atlantic: {
    id: :mid_atlantic,
    desired_position: { x: 640, y: 360 },  # Middle - Mid-Atlantic crossing
    type: :island,
    metadata: { name: "Mid-Atlantic" }
  },
  european_port: {
    id: :european_port,
    desired_position: { x: 1080, y: 360 },  # Right side - European destination
    type: :port,
    metadata: { name: "European Port" }
  }
}

# Find nearest accessible grid cell to a desired position
# Args:
#   desired_x, desired_y - Desired screen coordinates
#   max_search_radius - Maximum distance to search (in grid cells)
# Returns:
#   Hash with :x and :y screen coordinates of nearest accessible cell, or nil
def find_nearest_accessible_position(desired_x, desired_y, max_search_radius = 20)
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
      puts "[GRAPH] Created node #{id} at (#{accessible_pos[:x]}, #{accessible_pos[:y]})"
    else
      puts "WARNING: Could not find accessible position for waypoint #{id} at desired position (#{desired[:x]}, #{desired[:y]})"
    end
  end

  nodes
end

# Generate edges between nodes using pathfinding
# Creates bidirectional edges: for each A->B connection, also creates B->A with reversed path
# This ensures return journeys use the exact same squares as forward journeys
# Args:
#   nodes - Hash of node data
#   connections - Array of [from_id, to_id] pairs defining which nodes to connect
# Returns:
#   Array of edge hashes with paths and tile slots
def generate_edges(nodes, connections)
  edges = []
  # Track which edge pairs we've already created to avoid duplicates
  created_pairs = {}

  connections.each do |from_id, to_id|
    from_node = nodes[from_id]
    to_node = nodes[to_id]

    next unless from_node && to_node

    # Skip if we've already created this edge pair (bidirectional)
    pair_key = [from_id, to_id].sort
    next if created_pairs[pair_key]

    # Find path between nodes (only once per pair)
    path = find_path(
      from_node[:position][:x], from_node[:position][:y],
      to_node[:position][:x], to_node[:position][:y]
    )

    if path
      # Create edge with slots based on path length
      # Each path segment becomes a slot
      slots = [path.length - 1, 3].max  # Minimum 3 slots

      # Create forward edge (A->B)
      forward_edge = {
        id: "#{from_id}_to_#{to_id}".to_sym,
        from: from_id,
        to: to_id,
        slots: slots,
        tiles: Array.new(slots),
        path: path  # Store the full path for rendering
      }
      edges << forward_edge

      # Create reverse edge (B->A) using the reversed path
      # This ensures return journeys use the exact same squares
      reverse_path = path.reverse
      reverse_edge = {
        id: "#{to_id}_to_#{from_id}".to_sym,
        from: to_id,
        to: from_id,
        slots: slots,  # Same number of slots (same path length)
        tiles: Array.new(slots),
        path: reverse_path  # Reversed path - same squares, opposite direction
      }
      edges << reverse_edge

      # Mark this pair as created
      created_pairs[pair_key] = true

      puts "[GRAPH] Created bidirectional edge pair: #{from_id} <-> #{to_id} (#{slots} slots each)"
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
  # Only define forward connections - generate_edges will automatically create bidirectional edges
  # Outbound journey: Caribbean -> Mid-Atlantic -> European Port
  # Return journey is automatically created as reverse edges using the same paths
  connections = [
    # Outbound path (reverse edges created automatically)
    [:caribbean_port, :mid_atlantic],
    [:mid_atlantic, :european_port]
  ]

  # Generate edges with pathfinding
  edges = generate_edges(nodes, connections)

  {
    nodes: nodes,
    edges: edges,
    start_node: :caribbean_port,
    end_node: :european_port  # Victory condition: reach this node
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

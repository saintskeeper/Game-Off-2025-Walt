# Dynamic Graph System - Generates paths using navigation grid
#
# Core Concepts:
# - Load waypoint locations from generated JSON files (ports, islands)
# - Use pathfinding to generate valid paths between waypoints
# - Dynamically create edge slots based on path length
# - Ensure all paths follow accessible ocean routes
# - Smart connection strategy: ports connect to all ports, islands connect nearby

# Load pathfinding system (DragonRuby or standard Ruby)
begin
  require 'app/pathfinding_system.rb'
rescue
  require_relative 'pathfinding_system.rb'
end

# Data loader should already be loaded by graph_system.rb
# But we'll try to load it here as a fallback if needed
# Check if method exists using respond_to? (mruby-compatible alternative to defined?)
unless respond_to?(:load_all_waypoints)
  begin
    require 'app/data_loader.rb'
  rescue
    begin
      require_relative 'data_loader.rb'
    rescue => e
      puts "[GRAPH] WARNING: Could not load data_loader.rb: #{e.message}"
    end
  end
end

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
# Loads waypoints from JSON files and validates/adjusts positions to be accessible
# Returns:
#   Hash of node_id => node_data with accessible positions
def initialize_waypoint_nodes
  nodes = {}

  # Load waypoints from generated JSON files
  begin
    all_waypoints = load_all_waypoints
    puts "[GRAPH] Loaded #{all_waypoints.length} waypoints from JSON files"
    all_waypoints.each do |wp|
      puts "  - #{wp[:id]}: #{wp[:type]} at (#{wp[:position][:x]}, #{wp[:position][:y]}), #{wp[:grid_squares]&.length || 0} grid squares"
    end
  rescue => e
    puts "[GRAPH] ERROR calling load_all_waypoints: #{e.message}"
    puts "[GRAPH] Backtrace: #{e.backtrace.first(3).join("\n")}"
    all_waypoints = []
  end

  if all_waypoints.empty?
    puts "[GRAPH] WARNING: No waypoints loaded! Using fallback hardcoded waypoints."
    # Fallback to hardcoded waypoints if JSON files are missing
    fallback_waypoints = [
      { id: :caribbean_port, position: { x: 200, y: 360 }, type: :port, metadata: { name: "Caribbean Port" }, grid_squares: [] },
      { id: :european_port, position: { x: 1080, y: 360 }, type: :port, metadata: { name: "European Port" }, grid_squares: [] }
    ]
    all_waypoints = fallback_waypoints
  end

  all_waypoints.each do |waypoint|
    id = waypoint[:id]
    desired_pos = waypoint[:position]

    # Validate and adjust position to be accessible
    accessible_pos = find_nearest_accessible_position(desired_pos[:x], desired_pos[:y])

    if accessible_pos
      nodes[id] = {
        id: id,
        position: accessible_pos,
        type: waypoint[:type],
        metadata: waypoint[:metadata] || {},
        grid_squares: waypoint[:grid_squares] || []
      }

      # Log if position was adjusted
      if accessible_pos[:x] != desired_pos[:x] || accessible_pos[:y] != desired_pos[:y]
        puts "[GRAPH] Adjusted node #{id} from (#{desired_pos[:x]}, #{desired_pos[:y]}) to (#{accessible_pos[:x]}, #{accessible_pos[:y]})"
      else
        puts "[GRAPH] Created node #{id} at (#{accessible_pos[:x]}, #{accessible_pos[:y]})"
      end
    else
      puts "[GRAPH] WARNING: Could not find accessible position for waypoint #{id} at desired position (#{desired_pos[:x]}, #{desired_pos[:y]})"
    end
  end

  puts "[GRAPH] Initialized #{nodes.length} waypoint nodes"
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
      # Create edge with LIMITED slots for player tile placement
      # Path is kept full for smooth ship interpolation, but slots are capped
      # Max 3 slots per edge: gives 1-2 spots for player tiles between nodes
      slots = 3  # Fixed: start area, middle, end area

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

# Calculate distance between two nodes
# Args:
#   node1, node2 - Node hashes with :position keys
# Returns:
#   Float distance in screen pixels
def node_distance(node1, node2)
  dx = node1[:position][:x] - node2[:position][:x]
  dy = node1[:position][:y] - node2[:position][:y]
  Math.sqrt(dx * dx + dy * dy)
end

# Generate connections between waypoints using smart strategy
# Strategy:
#   - All ports connect to all other ports (full mesh)
#   - Islands connect to nearby ports/islands (within distance threshold)
# Args:
#   nodes - Hash of node_id => node_data
#   max_island_distance - Maximum distance for island connections (default: 500 pixels)
# Returns:
#   Array of [from_id, to_id] connection pairs
def generate_smart_connections(nodes, max_island_distance = 500)
  connections = []
  ports = []
  islands = []

  # Separate ports and islands
  nodes.each do |id, node|
    if node[:type] == :port
      ports << id
    elsif node[:type] == :island
      islands << id
    end
  end

  puts "[GRAPH] Connection strategy: #{ports.length} ports, #{islands.length} islands"

  # Connect all ports to all other ports (full mesh)
  ports.each_with_index do |port1, i|
    ports[(i+1)..-1].each do |port2|
      connections << [port1, port2]
    end
  end

  # Connect islands to nearby ports and islands
  islands.each do |island_id|
    island_node = nodes[island_id]

    # Connect to all ports
    ports.each do |port_id|
      connections << [island_id, port_id]
    end

    # Connect to nearby islands
    islands.each do |other_island_id|
      next if island_id == other_island_id

      distance = node_distance(island_node, nodes[other_island_id])
      if distance <= max_island_distance
        connections << [island_id, other_island_id]
      end
    end
  end

  puts "[GRAPH] Generated #{connections.length} connection pairs"
  connections
end

# Find start and end nodes (leftmost and rightmost ports)
# Args:
#   nodes - Hash of node_id => node_data
# Returns:
#   Hash with :start_node and :end_node symbol IDs
def find_start_end_nodes(nodes)
  ports = nodes.select { |id, node| node[:type] == :port }

  if ports.empty?
    # Fallback: use first and last nodes by ID
    node_ids = nodes.keys.sort
    return {
      start_node: node_ids.first,
      end_node: node_ids.last
    }
  end

  # Find leftmost (lowest x) and rightmost (highest x) ports
  leftmost = ports.min_by { |id, node| node[:position][:x] }
  rightmost = ports.max_by { |id, node| node[:position][:x] }

  {
    start_node: leftmost[0],
    end_node: rightmost[0]
  }
end

# Build dynamic graph with pathfinding
# Uses waypoints loaded from JSON files and generates connections automatically
# Returns:
#   Hash with nodes, edges, and metadata
def build_dynamic_graph
  # Initialize waypoint nodes at accessible positions
  nodes = initialize_waypoint_nodes

  if nodes.empty?
    puts "[GRAPH] ERROR: No valid waypoint nodes found!"
    return {
      nodes: {},
      edges: [],
      start_node: nil,
      end_node: nil
    }
  end

  # Generate connections using smart strategy
  connections = generate_smart_connections(nodes)

  # Generate edges with pathfinding
  edges = generate_edges(nodes, connections)

  # Find start and end nodes (leftmost and rightmost ports)
  start_end = find_start_end_nodes(nodes)

  puts "[GRAPH] Graph built: #{nodes.length} nodes, #{edges.length} edges"
  puts "[GRAPH] Start node: #{start_end[:start_node]}, End node: #{start_end[:end_node]}"

  {
    nodes: nodes,
    edges: edges,
    start_node: start_end[:start_node],
    end_node: start_end[:end_node]
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

# Graph System - Node-based path structure for ocean journey
#
# Core Concepts:
# - Nodes represent waypoints (ports, islands, locations)
# - Edges connect nodes and contain tile slots
# - Ship moves along edges from node to node
# - Paths are dynamically generated using navigation grid

# Load dynamic graph system (DragonRuby or standard Ruby)
begin
  require 'app/graph_system_dynamic.rb'
rescue LoadError
  require_relative 'graph_system_dynamic.rb'
end

# Generate dynamic graph on load (only once, cached in global variable)
# Use $ prefix for global variable to persist across file reloads in DragonRuby
# This prevents the graph from being regenerated on every file reload, which causes flickering
$dynamic_graph_cache ||= build_dynamic_graph
if $dynamic_graph_cache && !$dynamic_graph_initialized
  puts "Dynamic graph generated: #{$dynamic_graph_cache[:nodes].length} nodes, #{$dynamic_graph_cache[:edges].length} edges"
  $dynamic_graph_initialized = true
end

# Export nodes and edges for compatibility with existing code
# Only assign constants once to prevent flickering on file reloads
# Use a global flag to track if constants have been initialized
$path_nodes_initialized ||= false
unless $path_nodes_initialized
  PATH_NODES = $dynamic_graph_cache[:nodes]
  PATH_EDGES = $dynamic_graph_cache[:edges]
  $path_nodes_initialized = true
end

# Lookup edge by ID
# Args:
#   edge_id - Symbol identifying the edge
# Returns:
#   Hash representing the edge, or nil if not found
def get_edge(edge_id)
  PATH_EDGES.find { |edge| edge[:id] == edge_id }
end

# Find all edges leaving a specific node
# Args:
#   node_id - Symbol identifying the node
# Returns:
#   Array of edge hashes where edge[:from] == node_id
def get_outgoing_edges(node_id)
  PATH_EDGES.select { |edge| edge[:from] == node_id }
end

# Get the edge the ship is currently on
# Args:
#   state - Game state object containing ship data
# Returns:
#   Hash representing the current edge
def get_current_edge(state)
  get_edge(state.ship[:current_edge])
end

# Get available edge choices at branch points
# Returns empty array if ship is in middle of edge
# Returns array of edges if ship is at end of edge with multiple choices
# Args:
#   state - Game state object containing ship data
# Returns:
#   Array of edge hashes representing available choices
def get_next_edge_choices(state)
  current_edge = get_current_edge(state)
  return [] unless current_edge

  # Only show choices if at end of current edge
  return [] unless state.ship[:edge_progress] >= current_edge[:slots] - 1

  # Get all edges leaving the destination node of current edge
  outgoing = get_outgoing_edges(current_edge[:to])

  # Return choices only if there are multiple options
  outgoing.length > 1 ? outgoing : []
end

# Build default graph structure
# Initializes PATH_EDGES tile arrays
# Returns:
#   Hash containing graph metadata
def build_default_graph
  {
    nodes: PATH_NODES,
    edges: PATH_EDGES,
    start_node: :start
  }
end

# Graph System - Node-based path structure for ocean journey
#
# Core Concepts:
# - Nodes represent waypoints (ports, islands, locations)
# - Edges connect nodes and contain tile slots
# - Ship moves along edges from node to node
# - Paths are dynamically generated using navigation grid

# Load data loader first (needed by graph_system_dynamic)
begin
  require 'app/data_loader.rb'
rescue
  require_relative 'data_loader.rb'
end

# Load dynamic graph system (DragonRuby or standard Ruby)
begin
  require 'app/graph_system_dynamic.rb'
rescue
  require_relative 'graph_system_dynamic.rb'
end

# Graph cache version - increment to force rebuild when logic changes
GRAPH_CACHE_VERSION = 2  # v2: Limited slots per edge (3 max)

# Generate dynamic graph on load (only once, cached in global variable)
# Use $ prefix for global variable to persist across file reloads in DragonRuby
# This prevents the graph from being regenerated on every file reload, which causes flickering
# Force rebuild if cache is empty, invalid, or version mismatch
cache_invalid = !$dynamic_graph_cache ||
                !$dynamic_graph_cache[:nodes] ||
                $dynamic_graph_cache[:nodes].empty? ||
                !$dynamic_graph_cache[:edges] ||
                $dynamic_graph_cache[:edges].empty? ||
                $dynamic_graph_cache[:version] != GRAPH_CACHE_VERSION
if cache_invalid
  puts "[GRAPH] Building dynamic graph (cache invalid or version #{$dynamic_graph_cache&.dig(:version) || 'nil'} != #{GRAPH_CACHE_VERSION})..."
  $dynamic_graph_cache = build_dynamic_graph
  $dynamic_graph_cache[:version] = GRAPH_CACHE_VERSION
  $dynamic_graph_initialized = false  # Reset flag to allow logging
end

if $dynamic_graph_cache && !$dynamic_graph_initialized
  node_count = $dynamic_graph_cache[:nodes] ? $dynamic_graph_cache[:nodes].length : 0
  edge_count = $dynamic_graph_cache[:edges] ? $dynamic_graph_cache[:edges].length : 0
  node_ids = $dynamic_graph_cache[:nodes] ? $dynamic_graph_cache[:nodes].keys.join(', ') : 'none'
  puts "[GRAPH] Dynamic graph generated: #{node_count} nodes, #{edge_count} edges"
  puts "[GRAPH] Node IDs: #{node_ids}"
  $dynamic_graph_initialized = true
end

# Note: Graph data is now stored in args.state.path_nodes and args.state.path_edges
# Access them directly instead of using constants to prevent hot-reload issues

# Lookup edge by ID
# Args:
#   state - Game state object containing graph data
#   edge_id - Symbol identifying the edge
# Returns:
#   Hash representing the edge, or nil if not found
def get_edge(state, edge_id)
  state.path_edges.find { |edge| edge[:id] == edge_id }
end

# Find all edges leaving a specific node
# Args:
#   state - Game state object containing graph data
#   node_id - Symbol identifying the node
# Returns:
#   Array of edge hashes where edge[:from] == node_id
def get_outgoing_edges(state, node_id)
  state.path_edges.select { |edge| edge[:from] == node_id }
end

# Get the edge the ship is currently on
# Args:
#   state - Game state object containing ship data
# Returns:
#   Hash representing the current edge
def get_current_edge(state)
  get_edge(state, state.ship[:current_edge])
end

# Get available edge choices at branch points
# Returns empty array if ship is in middle of edge
# Returns array of edges if ship is at end of edge with choices available
# More robust: always shows available edges when at a node (allows return journeys from any node)
# Args:
#   state - Game state object containing ship data
# Returns:
#   Array of edge hashes representing available choices
def get_next_edge_choices(state)
  current_edge = get_current_edge(state)
  return [] unless current_edge

  # Only show choices if at end of current edge (at or past the last slot)
  # When edge_progress >= slots, we've reached the destination node
  # Use >= slots (not slots - 1) to match check_edge_complete logic
  at_end = state.ship[:edge_progress] >= current_edge[:slots]

  # Also allow showing choices when at the last slot (slots - 1) for better UX
  at_last_slot = state.ship[:edge_progress] >= current_edge[:slots] - 1

  return [] unless at_last_slot

  # Get all edges leaving the destination node of current edge
  outgoing = get_outgoing_edges(state, current_edge[:to])

  # More robust: always show choices when there are outgoing edges
  # This allows return journeys from any node, not just European port
  # Previously only showed if multiple options OR at European port
  if outgoing.length > 0
    # Debug output for return journeys
    end_node = state.end_node || :european_port
    is_at_european_port = current_edge[:to] == end_node
    if is_at_european_port || state.ship[:journey_phase] == :return
      puts "[DEBUG] get_next_edge_choices at #{current_edge[:to]}:"
      puts "  - Current edge: #{current_edge[:id]}"
      puts "  - Progress: #{state.ship[:edge_progress]}/#{current_edge[:slots]}"
      puts "  - Found #{outgoing.length} outgoing edge(s): #{outgoing.map { |e| "#{e[:id]} -> #{e[:to]}" }.join(', ')}"
    end
    return outgoing
  end

  # No outgoing edges available
  []
end

# Build default graph structure
# Initializes path_edges tile arrays
# Returns:
#   Hash containing graph metadata
def build_default_graph(state)
  {
    nodes: state.path_nodes,
    edges: state.path_edges,
    start_node: state.start_node || :caribbean_port,
    end_node: state.end_node || :european_port
  }
end

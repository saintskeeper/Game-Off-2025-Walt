# Input Handler - Handles mouse click interactions
#
# Core Concepts:
# - DragonRuby: args.inputs.mouse.click is truthy on click frame
# - args.inputs.mouse.point gives {x, y} of cursor
# - Collision: args.geometry.inside_rect?(point, rect)
# - Three-phase click: select from hand, choose path at branch, or place/move on slot
#
# Integration:
# - Called from main.rb each tick
# - Uses graph_system.rb for node/edge queries
# - Uses navigation_system.rb for ship movement
# - Uses tile_system.rb for tile placement

# Require systems for navigation and tile placement
require 'app/graph_system.rb'
require 'app/navigation_system.rb'
require 'app/tile_system.rb'

# Constants for hand tile positioning on screen
# Hand tiles are displayed at the bottom of the screen
HAND_START_X = 440  # Starting X position of first tile
HAND_Y = 50         # Y position (bottom of screen)
HAND_TILE_SIZE = 80  # Size of each tile in hand (width and height)
HAND_SPACING = 100   # Spacing between tiles in hand

# Checks if a slot index is rendered (visible) based on the rendering logic
# Slots are rendered if: first (0), last, or odd-indexed
# Even-indexed slots (except first/last) are skipped
# Args:
#   slot_index - Index of the slot to check
#   total_slots - Total number of slots on the edge
# Returns:
#   Boolean - true if the slot is rendered/visible
def slot_is_rendered?(slot_index, total_slots)
  is_first = slot_index == 0
  is_last = slot_index == total_slots - 1
  is_even = slot_index.even?

  # Render if first, last, or odd-indexed
  is_first || is_last || !is_even
end

# Finds all visible (rendered) slots that are reachable from current position
# These are the slots the player can click on to move forward
# Args:
#   current_progress - Current ship position (slot index)
#   total_slots - Total number of slots on the edge
# Returns:
#   Array of slot indices that are visible and ahead of current position
def find_reachable_visible_slots(current_progress, total_slots)
  reachable = []

  # Check all slots ahead of current position
  (current_progress + 1...total_slots).each do |i|
    if slot_is_rendered?(i, total_slots)
      reachable << i
    end
  end

  reachable
end

# Main input handling function - processes mouse clicks each tick
# Handles multi-phase interaction:
#   1. Select tile from hand
#   2. Choose path at branch points
#   3. Place tile on slot or advance ship
# Args:
#   args - DragonRuby args object containing inputs and state
def handle_input(args)
  # Only process input on frames where mouse was clicked
  return unless args.inputs.mouse.click

  # Get mouse position for collision detection
  mouse = args.inputs.mouse.point

  # Phase 1: Check if clicked on a tile in hand
  args.state.hand.each_with_index do |tile, i|
    rect = hand_tile_rect(i)
    if args.geometry.inside_rect?(mouse, rect)
      args.state.selected_tile = i
      return  # Exit early - tile selected
    end
  end

  # Phase 2: Check for branch point node clicks (path selection)
  # If ship is at a branch point, allow clicking destination nodes
  next_edges = get_next_edge_choices(args.state)
  unless next_edges.empty?
    # Debug: log available choices
    puts "[DEBUG] Available edge choices: #{next_edges.map { |e| "#{e[:id]} -> #{e[:to]}" }.join(', ')}"
    puts "[DEBUG] Mouse position: (#{mouse[:x]}, #{mouse[:y]})"

    next_edges.each do |edge|
      to_node = args.state.path_nodes[edge[:to]]
      next unless to_node  # Skip if node doesn't exist

      # Make clickable area larger for better usability (especially for ports)
      # Use larger rectangle for ports, standard for other nodes
      is_port = to_node[:type] == :port
      click_size = is_port ? 30 : 20  # Larger click area for ports

      node_rect = {
        x: to_node[:position][:x] - click_size,
        y: to_node[:position][:y] - click_size,
        w: click_size * 2,
        h: click_size * 2
      }

      # Debug: show clickable area for return paths
      end_node = args.state.end_node || :european_port
      current_edge = get_current_edge(args.state)
      if current_edge && current_edge[:to] == end_node
        puts "[DEBUG] Checking click on return path node #{edge[:to]}:"
        puts "  - Node position: (#{to_node[:position][:x]}, #{to_node[:position][:y]})"
        puts "  - Clickable rect: (#{node_rect[:x]}, #{node_rect[:y]}) size #{node_rect[:w]}x#{node_rect[:h]}"
        puts "  - Mouse in rect: #{args.geometry.inside_rect?(mouse, node_rect)}"
      end

      if args.geometry.inside_rect?(mouse, node_rect)
        puts "[DEBUG] ✅ Clicked on return path node: #{edge[:to]} (edge: #{edge[:id]})"
        advance_ship(args, edge[:id])
        return  # Exit early - path chosen
      end
    end

    # Also allow clicking on the current destination node if we're at European port
    # This provides an alternative way to start the return journey
    current_edge = get_current_edge(args.state)
    if current_edge
      end_node = args.state.end_node || :european_port
      if current_edge[:to] == end_node && args.state.ship[:journey_phase] == :return
        # Check if clicked on European port itself - start return journey
        european_port_node = args.state.path_nodes[end_node]
        if european_port_node
          port_rect = {
            x: european_port_node[:position][:x] - 30,
            y: european_port_node[:position][:y] - 30,
            w: 60,
            h: 60
          }

          if args.geometry.inside_rect?(mouse, port_rect) && next_edges.length > 0
            # Clicked on European port - start return journey with first available edge
            puts "[DEBUG] Clicked on European port - starting return journey"
            advance_ship(args, next_edges.first[:id])
            return
          end
        end
      end
    end
  end

  # Phase 3: Check if clicked on a slot on current edge
  # Either place tile (if selected) or advance ship to next slot
  # For movement: identify visible slots we can move to and allow clicking them
  current_edge = get_current_edge(args.state)
  current_progress = args.state.ship[:edge_progress]

  # Find which visible slots are reachable (ahead of current position)
  reachable_slots = find_reachable_visible_slots(current_progress, current_edge[:slots])

  current_edge[:slots].times do |i|
    rect = edge_slot_rect(args.state, current_edge[:id], i)

    next unless args.geometry.inside_rect?(mouse, rect)

    if args.state.selected_tile
      # Placing a tile - can place on any slot (including skipped/not-rendered ones)
      place_tile_on_edge(args, current_edge[:id], i)
      return  # Exit early - tile placed
    elsif reachable_slots.include?(i)
      # Movement: clicked on a reachable visible slot
      # Advance ship forward one slot (sequential movement through all slots)
      # The ship will move through all slots, including invisible ones
      advance_ship(args)
      return  # Exit early - ship advanced
    end
  end

  # Phase 4: Clicked elsewhere - deselect
  args.state.selected_tile = nil
end

# Calculates the collision rectangle for a tile in the player's hand
# Used for click detection to determine which hand tile was clicked
# Args:
#   index - Index (0-2) of the tile in the hand array
# Returns:
#   Hash with :x, :y, :w, :h keys for collision detection
def hand_tile_rect(index)
  {
    x: HAND_START_X + (index * HAND_SPACING),
    y: HAND_Y,
    w: HAND_TILE_SIZE,
    h: HAND_TILE_SIZE
  }
end


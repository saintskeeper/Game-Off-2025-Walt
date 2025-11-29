# Pathfinding System - A* pathfinding on navigation grid
#
# Core Concepts:
# - Uses A* algorithm to find optimal paths through navigation grid
# - Grid coordinates are scaled to/from screen coordinates
# - Only navigates through accessible (ocean) cells
# - Returns array of screen coordinate waypoints

# Load navigation grid (DragonRuby or standard Ruby)
begin
  require 'data/navigation_grid.rb'
rescue LoadError
  require_relative '../data/navigation_grid.rb'
end

# Screen and grid dimensions
SCREEN_WIDTH = 1280
SCREEN_HEIGHT = 720
MAP_IMAGE_WIDTH = 309
MAP_IMAGE_HEIGHT = 147

# Convert screen coordinates to grid coordinates
# Args:
#   screen_x, screen_y - Screen pixel coordinates (DragonRuby grid space)
# Returns:
#   Hash with :x and :y keys for grid coordinates
def screen_to_grid(screen_x, screen_y)
  # Scale screen coordinates to map image coordinates
  map_x = (screen_x * MAP_IMAGE_WIDTH) / SCREEN_WIDTH
  map_y = (screen_y * MAP_IMAGE_HEIGHT) / SCREEN_HEIGHT

  # Convert map coordinates to grid coordinates
  grid_x = (map_x * NAVIGATION_GRID[0].length) / MAP_IMAGE_WIDTH
  grid_y = (map_y * NAVIGATION_GRID.length) / MAP_IMAGE_HEIGHT

  # IMPORTANT: Flip Y axis - DragonRuby has Y=0 at bottom, but image has Y=0 at top
  grid_y_flipped = NAVIGATION_GRID.length - 1 - grid_y.floor

  { x: grid_x.floor, y: grid_y_flipped }
end

# Convert grid coordinates to screen coordinates (center of grid cell)
# Args:
#   grid_x, grid_y - Grid coordinates (with flipped Y)
# Returns:
#   Hash with :x and :y keys for screen coordinates
def grid_to_screen(grid_x, grid_y)
  grid_width = NAVIGATION_GRID[0].length
  grid_height = NAVIGATION_GRID.length

  # Flip Y back to image coordinates
  grid_y_image = grid_height - 1 - grid_y

  # Convert grid to map coordinates (center of cell)
  map_x = ((grid_x + 0.5) * MAP_IMAGE_WIDTH) / grid_width
  map_y = ((grid_y_image + 0.5) * MAP_IMAGE_HEIGHT) / grid_height

  # Scale map coordinates to screen coordinates
  screen_x = (map_x * SCREEN_WIDTH) / MAP_IMAGE_WIDTH
  screen_y = (map_y * SCREEN_HEIGHT) / MAP_IMAGE_HEIGHT

  { x: screen_x.floor, y: screen_y.floor }
end

# Check if grid coordinates are valid and accessible
# Args:
#   grid_x, grid_y - Grid coordinates
# Returns:
#   Boolean - true if valid and accessible
def grid_cell_accessible?(grid_x, grid_y)
  return false if grid_x < 0 || grid_y < 0
  return false if grid_y >= NAVIGATION_GRID.length
  return false if grid_x >= NAVIGATION_GRID[0].length

  NAVIGATION_GRID[grid_y][grid_x]
end

# Get neighboring grid cells (4-connected: up, down, left, right)
# Args:
#   grid_x, grid_y - Grid coordinates
# Returns:
#   Array of hashes with :x and :y keys for accessible neighbors
def get_grid_neighbors(grid_x, grid_y)
  neighbors = []

  # 4-connected neighbors (no diagonal movement)
  [[0, 1], [0, -1], [1, 0], [-1, 0]].each do |dx, dy|
    nx = grid_x + dx
    ny = grid_y + dy

    neighbors << { x: nx, y: ny } if grid_cell_accessible?(nx, ny)
  end

  neighbors
end

# Manhattan distance heuristic for A*
# Args:
#   ax, ay - Start coordinates
#   bx, by - End coordinates
# Returns:
#   Integer distance
def manhattan_distance(ax, ay, bx, by)
  (ax - bx).abs + (ay - by).abs
end

# A* pathfinding algorithm
# Finds optimal path through navigation grid
# Args:
#   start_x, start_y - Starting screen coordinates
#   end_x, end_y - Ending screen coordinates
# Returns:
#   Array of screen coordinate hashes [{x:, y:}, ...] or nil if no path found
def find_path(start_x, start_y, end_x, end_y)
  # Convert to grid coordinates
  start_grid = screen_to_grid(start_x, start_y)
  end_grid = screen_to_grid(end_x, end_y)

  # Validate start and end positions
  return nil unless grid_cell_accessible?(start_grid[:x], start_grid[:y])
  return nil unless grid_cell_accessible?(end_grid[:x], end_grid[:y])

  # A* algorithm
  open_set = [start_grid]
  came_from = {}

  g_score = Hash.new(Float::INFINITY)
  g_score[[start_grid[:x], start_grid[:y]]] = 0

  f_score = Hash.new(Float::INFINITY)
  f_score[[start_grid[:x], start_grid[:y]]] = manhattan_distance(
    start_grid[:x], start_grid[:y],
    end_grid[:x], end_grid[:y]
  )

  while open_set.any?
    # Find node with lowest f_score
    current = open_set.min_by { |node| f_score[[node[:x], node[:y]]] }

    # Check if we reached the goal
    if current[:x] == end_grid[:x] && current[:y] == end_grid[:y]
      # Reconstruct path
      path = [current]
      while came_from[[current[:x], current[:y]]]
        current = came_from[[current[:x], current[:y]]]
        path.unshift(current)
      end

      # Convert grid path to screen coordinates
      return path.map { |node| grid_to_screen(node[:x], node[:y]) }
    end

    open_set.delete(current)

    # Check all neighbors
    get_grid_neighbors(current[:x], current[:y]).each do |neighbor|
      tentative_g = g_score[[current[:x], current[:y]]] + 1

      if tentative_g < g_score[[neighbor[:x], neighbor[:y]]]
        came_from[[neighbor[:x], neighbor[:y]]] = current
        g_score[[neighbor[:x], neighbor[:y]]] = tentative_g
        f_score[[neighbor[:x], neighbor[:y]]] = tentative_g + manhattan_distance(
          neighbor[:x], neighbor[:y],
          end_grid[:x], end_grid[:y]
        )

        open_set << neighbor unless open_set.include?(neighbor)
      end
    end
  end

  # No path found
  nil
end

# Find a random accessible position on the grid
# Useful for generating random waypoints
# Returns:
#   Hash with :x and :y keys for screen coordinates, or nil if no accessible cells
def find_random_accessible_position
  accessible_cells = []

  NAVIGATION_GRID.each_with_index do |row, y|
    row.each_with_index do |cell, x|
      accessible_cells << { x: x, y: y } if cell
    end
  end

  return nil if accessible_cells.empty?

  random_cell = accessible_cells.sample
  grid_to_screen(random_cell[:x], random_cell[:y])
end

# Generate a series of waypoints that form a valid path
# Useful for creating game loops/routes
# Args:
#   num_waypoints - Number of waypoints to generate
# Returns:
#   Array of screen coordinate hashes, forming a connected path
def generate_waypoint_path(num_waypoints = 5)
  waypoints = []

  # Start with a random accessible position
  current_pos = find_random_accessible_position
  return [] unless current_pos

  waypoints << current_pos

  # Generate remaining waypoints
  (num_waypoints - 1).times do
    # Find a random accessible position
    next_pos = find_random_accessible_position
    next unless next_pos

    # Ensure it's different from current position
    next if next_pos[:x] == current_pos[:x] && next_pos[:y] == current_pos[:y]

    waypoints << next_pos
    current_pos = next_pos
  end

  waypoints
end

# Rendering Helpers - Utility functions for rendering operations
#
# These are pure utility functions that assist with rendering operations
# but don't directly interact with args or state. They can be used across
# different rendering contexts.

# Creates dotted line segments from a start point to an end point
# Treasure map style: red dotted line
# Args:
#   x1, y1 - Start point coordinates
#   x2, y2 - End point coordinates
#   dot_length - Length of each dot segment (default: 6 for visible dots)
#   gap_length - Length of gap between dots (default: 10 for classic dotted look)
#   color - Hash with :r, :g, :b color values (default: red for treasure map)
# Returns:
#   Array of line hash primitives representing the dotted line
def create_dotted_line(x1, y1, x2, y2, dot_length: 6, gap_length: 10, color: { r: 180, g: 60, b: 60 })
  # Calculate total distance and direction
  dx = x2 - x1
  dy = y2 - y1
  distance = Math.sqrt(dx * dx + dy * dy)

  return [] if distance < 0.1  # Too short to draw

  # Normalize direction vector
  unit_x = dx / distance
  unit_y = dy / distance

  # Create dotted segments
  segments = []
  current_distance = 0

  while current_distance < distance
    # Start of current dot
    dot_start_x = x1 + unit_x * current_distance
    dot_start_y = y1 + unit_y * current_distance

    # End of current dot (don't exceed total distance)
    dot_end_distance = [current_distance + dot_length, distance].min
    dot_end_x = x1 + unit_x * dot_end_distance
    dot_end_y = y1 + unit_y * dot_end_distance

    # Add this dot segment with specified color
    segments << {
      x: dot_start_x, y: dot_start_y,
      x2: dot_end_x, y2: dot_end_y
    }.merge(color)

    # Move to next dot (skip gap)
    current_distance += dot_length + gap_length
  end

  segments
end


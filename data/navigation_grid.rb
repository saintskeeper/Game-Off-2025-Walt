# Navigation Grid - Generated from world map image
# True = accessible (ocean), False = blocked (land/edge)
#
# Grid dimensions: 30x14
# Scale factor: 10 (each cell = 10x10 pixels)
# Image size: 309x147
#
# Usage:
#   # Convert screen coordinates to grid coordinates
#   grid_x = (screen_x * 30) / 309
#   grid_y = (screen_y * 14) / 147
#   accessible = NAVIGATION_GRID[grid_y][grid_x]

NAVIGATION_GRID = [
  [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
  [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
  [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
  [false, false, false, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
  [false, false, false, false, false, false, false, false, false, false, true, true, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
  [false, false, false, false, false, false, false, false, false, false, true, true, true, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
  [false, false, false, false, false, false, false, false, true, true, false, true, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
  [false, false, false, false, true, false, true, true, true, true, false, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
  [false, false, false, true, true, true, true, false, false, true, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
  [false, false, false, true, true, true, false, false, false, false, false, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
  [false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
  [false, false, false, false, false, false, false, false, false, false, true, true, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
  [false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
  [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
]

# Check if screen coordinates are on an accessible path
# Args:
#   screen_x, screen_y - Screen pixel coordinates (DragonRuby grid space)
# Returns:
#   Boolean - true if accessible, false if blocked
def screen_position_accessible?(screen_x, screen_y)
  # Scale to map coordinates
  map_x = (screen_x * 309) / 1280
  map_y = (screen_y * 147) / 720

  # Convert to grid coordinates
  grid_x = ((map_x * 30) / 309).floor
  grid_y_image = ((map_y * 14) / 147).floor

  # Flip Y axis for DragonRuby (Y=0 at bottom)
  grid_y = 14 - 1 - grid_y_image

  return false if grid_x < 0 || grid_x >= 30
  return false if grid_y < 0 || grid_y >= 14

  NAVIGATION_GRID[grid_y][grid_x]
end

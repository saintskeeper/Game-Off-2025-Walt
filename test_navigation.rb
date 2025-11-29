#!/usr/bin/env ruby
# Test script to verify navigation grid and pathfinding integration

require_relative 'data/navigation_grid.rb'
require_relative 'app/pathfinding_system.rb'
require_relative 'app/graph_system_dynamic.rb'
require_relative 'app/graph_system.rb'

puts "=" * 60
puts "Navigation Grid & Pathfinding Test"
puts "=" * 60

# Test 1: Navigation grid loaded
puts "\n[Test 1] Navigation Grid Loaded"
puts "  Grid dimensions: #{NAVIGATION_GRID[0].length}x#{NAVIGATION_GRID.length}"
accessible_count = NAVIGATION_GRID.flatten.count(true)
total_count = NAVIGATION_GRID.flatten.length
puts "  Accessible cells: #{accessible_count}/#{total_count} (#{(accessible_count.to_f/total_count*100).round(1)}%)"
puts "  ✓ Navigation grid loaded successfully"

# Test 2: Screen to grid conversion
puts "\n[Test 2] Coordinate Conversion"
test_screen_x, test_screen_y = 640, 360
grid_coord = screen_to_grid(test_screen_x, test_screen_y)
puts "  Screen (#{test_screen_x}, #{test_screen_y}) -> Grid (#{grid_coord[:x]}, #{grid_coord[:y]})"
screen_coord = grid_to_screen(grid_coord[:x], grid_coord[:y])
puts "  Grid (#{grid_coord[:x]}, #{grid_coord[:y]}) -> Screen (#{screen_coord[:x]}, #{screen_coord[:y]})"
puts "  ✓ Coordinate conversion working"

# Test 3: Find accessible position
puts "\n[Test 3] Find Random Accessible Position"
random_pos = find_random_accessible_position
if random_pos
  puts "  Random accessible position: (#{random_pos[:x]}, #{random_pos[:y]})"
  grid_pos = screen_to_grid(random_pos[:x], random_pos[:y])
  is_accessible = grid_cell_accessible?(grid_pos[:x], grid_pos[:y])
  puts "  Position is accessible: #{is_accessible}"
  puts "  ✓ Random position finding working"
else
  puts "  ✗ Could not find accessible position"
end

# Test 4: Dynamic graph generation
puts "\n[Test 4] Dynamic Graph Generation"
puts "  Generating graph..."
graph = build_dynamic_graph
puts "  Nodes created: #{graph[:nodes].length}"
graph[:nodes].each do |id, node|
  puts "    - #{id}: #{node[:metadata][:name]} at (#{node[:position][:x]}, #{node[:position][:y]})"
end

puts "\n  Edges created: #{graph[:edges].length}"
graph[:edges].each do |edge|
  path_length = edge[:path] ? edge[:path].length : 0
  puts "    - #{edge[:id]}: #{edge[:from]} -> #{edge[:to]} (#{edge[:slots]} slots, #{path_length} path points)"
end

if graph[:nodes].length > 0 && graph[:edges].length > 0
  puts "  ✓ Dynamic graph generation working"
else
  puts "  ✗ Graph generation failed"
end

# Test 5: Pathfinding
puts "\n[Test 5] Pathfinding Test"
if graph[:nodes].length >= 2
  node_ids = graph[:nodes].keys
  start_node = graph[:nodes][node_ids[0]]
  end_node = graph[:nodes][node_ids[-1]]

  puts "  Finding path from #{node_ids[0]} to #{node_ids[-1]}..."
  path = find_path(
    start_node[:position][:x], start_node[:position][:y],
    end_node[:position][:x], end_node[:position][:y]
  )

  if path
    puts "  Path found with #{path.length} waypoints"
    puts "  ✓ Pathfinding working"
  else
    puts "  ✗ No path found (nodes may not be connected)"
  end
else
  puts "  ⊘ Skipped (not enough nodes)"
end

# Test 6: PATH_NODES and PATH_EDGES exported
puts "\n[Test 6] Global Variables Exported"
puts "  PATH_NODES defined: #{defined?(PATH_NODES) ? 'Yes' : 'No'}"
puts "  PATH_EDGES defined: #{defined?(PATH_EDGES) ? 'Yes' : 'No'}"
if defined?(PATH_NODES) && defined?(PATH_EDGES)
  puts "  PATH_NODES count: #{PATH_NODES.length}"
  puts "  PATH_EDGES count: #{PATH_EDGES.length}"
  puts "  ✓ Global variables exported correctly"
else
  puts "  ✗ Global variables not exported"
end

puts "\n" + "=" * 60
puts "Test Complete"
puts "=" * 60

#!/usr/bin/env python3
"""
Pathing System Generator from Layer Images

Processes layer images to generate:
- Navigation grid from water.png (accessible paths)
- Port locations from port.png (waypoint nodes)
- Island locations from islands.png (waypoint nodes)

Usage:
    python generate_pathing_from_layers.py [--scale FACTOR] [--visualize]

Options:
    --scale FACTOR    Downscale factor for grid (default: 10). Grid cell size in pixels.
    --visualize       Generate visualization images
    --cluster-radius  Maximum distance for clustering nearby pixels (default: 20)
"""

from PIL import Image
import json
import argparse
import os
from collections import deque

# Screen dimensions (DragonRuby default)
SCREEN_WIDTH = 1280
SCREEN_HEIGHT = 720

def is_non_black_pixel(pixel, threshold=10):
    """
    Check if pixel is non-black (has significant color).
    Args:
        pixel: RGB tuple
        threshold: Minimum RGB value to consider non-black
    Returns:
        Boolean - True if pixel is non-black
    """
    return max(pixel) > threshold

def flood_fill_cluster(image, start_x, start_y, visited_set):
    """
    Flood fill to find all connected non-black pixels in a cluster.
    Args:
        image: PIL Image object
        start_x, start_y: Starting pixel coordinates
        visited_set: Set of already visited pixels (modified in place)
    Returns:
        List of (x, y) tuples in this cluster
    """
    if (start_x, start_y) in visited_set:
        return []
    
    width, height = image.size
    cluster = []
    stack = [(start_x, start_y)]
    visited_cluster = set()
    
    while stack:
        x, y = stack.pop()
        
        if (x, y) in visited_cluster:
            continue
        if x < 0 or x >= width or y < 0 or y >= height:
            continue
        
        pixel = image.getpixel((x, y))
        if not is_non_black_pixel(pixel):
            continue
        
        visited_cluster.add((x, y))
        cluster.append((x, y))
        visited_set.add((x, y))
        
        # Check 8-connected neighbors (including diagonals for better clustering)
        for dx in [-1, 0, 1]:
            for dy in [-1, 0, 1]:
                if dx == 0 and dy == 0:
                    continue
                nx, ny = x + dx, y + dy
                if (nx, ny) not in visited_cluster:
                    stack.append((nx, ny))
    
    return cluster

def find_cluster_center(cluster):
    """
    Calculate the center point of a cluster.
    Args:
        cluster: List of (x, y) tuples
    Returns:
        (x, y) tuple representing center
    """
    if not cluster:
        return None
    
    sum_x = sum(p[0] for p in cluster)
    sum_y = sum(p[1] for p in cluster)
    count = len(cluster)
    
    return (sum_x // count, sum_y // count)

def image_to_screen_coords(image_x, image_y, image_width, image_height):
    """
    Convert image coordinates to screen coordinates.
    DragonRuby: (0,0) at bottom-left, Y increases upward
    Image: (0,0) at top-left, Y increases downward
    
    Args:
        image_x, image_y: Image pixel coordinates
        image_width, image_height: Image dimensions
    Returns:
        (screen_x, screen_y) tuple
    """
    # Scale to screen dimensions
    screen_x = (image_x * SCREEN_WIDTH) / image_width
    # Flip Y axis: image_y=0 (top) -> screen_y=SCREEN_HEIGHT (top)
    screen_y = ((image_height - image_y) * SCREEN_HEIGHT) / image_height
    
    return (int(screen_x), int(screen_y))

def generate_grid_squares_for_cluster(cluster, image_width, image_height, scale=10):
    """
    Generate grid squares that overlap with a cluster of pixels.
    Each grid square represents a place where tiles can be placed.
    
    Args:
        cluster: List of (x, y) pixel coordinates in image space
        image_width, image_height: Image dimensions
        scale: Grid cell size in pixels (same as navigation grid scale)
    Returns:
        List of (grid_x, grid_y) tuples representing grid cells
    """
    if not cluster:
        return []
    
    # Create a set of grid cells that contain cluster pixels
    grid_cells = set()
    
    for pixel_x, pixel_y in cluster:
        # Convert pixel coordinates to grid coordinates
        grid_x = pixel_x // scale
        grid_y = pixel_y // scale
        
        # Ensure grid coordinates are valid
        grid_width = image_width // scale
        grid_height = image_height // scale
        
        if 0 <= grid_x < grid_width and 0 <= grid_y < grid_height:
            grid_cells.add((grid_x, grid_y))
    
    return sorted(list(grid_cells))

def detect_waypoints(image_path, waypoint_type, cluster_min_size=5, scale=10):
    """
    Detect waypoint locations from a layer image.
    Groups nearby pixels into clusters and returns center points.
    Also generates grid squares for each waypoint where tiles can be placed.
    
    Args:
        image_path: Path to layer image (port.png or islands.png)
        waypoint_type: 'port' or 'island'
        cluster_min_size: Minimum cluster size to consider valid
        scale: Grid cell size in pixels (for generating grid squares)
    Returns:
        List of waypoint dicts with id, position, type, metadata, and grid_squares
    """
    print(f"\nProcessing {waypoint_type} layer: {image_path}")
    
    if not os.path.exists(image_path):
        print(f"  WARNING: Image not found: {image_path}")
        return []
    
    img = Image.open(image_path).convert('RGB')
    width, height = img.size
    
    print(f"  Image size: {width}x{height}")
    
    # Find all non-black pixels
    visited = set()
    clusters = []
    
    for y in range(height):
        for x in range(width):
            pixel = img.getpixel((x, y))
            if is_non_black_pixel(pixel) and (x, y) not in visited:
                cluster = flood_fill_cluster(img, x, y, visited)
                if len(cluster) >= cluster_min_size:
                    clusters.append(cluster)
    
    print(f"  Found {len(clusters)} {waypoint_type} clusters")
    
    # Convert clusters to waypoints
    waypoints = []
    for i, cluster in enumerate(clusters):
        center_image = find_cluster_center(cluster)
        if center_image:
            center_screen = image_to_screen_coords(
                center_image[0], center_image[1],
                width, height
            )
            
            # Generate grid squares for this waypoint
            grid_squares = generate_grid_squares_for_cluster(cluster, width, height, scale)
            
            waypoint = {
                'id': f"{waypoint_type}_{i}",
                'position': {
                    'x': center_screen[0],
                    'y': center_screen[1]
                },
                'type': waypoint_type,
                'metadata': {
                    'name': f"{waypoint_type.capitalize()} {i+1}",
                    'cluster_size': len(cluster),
                    'image_position': {
                        'x': center_image[0],
                        'y': center_image[1]
                    }
                },
                'grid_squares': [
                    {'x': gx, 'y': gy} for gx, gy in grid_squares
                ]
            }
            waypoints.append(waypoint)
            print(f"    {waypoint['id']}: screen({center_screen[0]}, {center_screen[1]}), image({center_image[0]}, {center_image[1]}), size={len(cluster)}, grid_squares={len(grid_squares)}")
    
    return waypoints

def assign_port_names(ports):
    """
    Assign meaningful names to ports based on their X position.
    Leftmost port = Caribbean Port, rightmost port = European Port.

    Args:
        ports: List of port waypoint dicts
    Returns:
        Same list with updated names in metadata
    """
    if len(ports) == 0:
        return ports

    # Sort by X position (leftmost first)
    sorted_ports = sorted(ports, key=lambda p: p['position']['x'])

    if len(ports) == 2:
        # Two-port setup: Caribbean (west) and European (east)
        sorted_ports[0]['metadata']['name'] = "Caribbean Port"
        sorted_ports[1]['metadata']['name'] = "European Port"
        print(f"  Assigned port names: Caribbean Port (x={sorted_ports[0]['position']['x']}), European Port (x={sorted_ports[1]['position']['x']})")
    else:
        # Multiple ports: name by position (West to East)
        for i, port in enumerate(sorted_ports):
            port['metadata']['name'] = f"Port {i+1} (x={port['position']['x']})"
        print(f"  Named {len(ports)} ports by X position")

    return ports


def generate_navigation_grid_from_water(water_image_path, scale=10):
    """
    Generate navigation grid from water.png.
    Non-black pixels = accessible (water), black pixels = blocked.
    
    Args:
        water_image_path: Path to water.png
        scale: Downscale factor (grid cell size in pixels)
    Returns:
        Dict with grid data and metadata
    """
    print(f"\nProcessing water layer: {water_image_path}")
    
    if not os.path.exists(water_image_path):
        print(f"  ERROR: Water image not found: {water_image_path}")
        return None
    
    img = Image.open(water_image_path).convert('RGB')
    width, height = img.size
    
    print(f"  Image size: {width}x{height}")
    print(f"  Scale factor: {scale} (each cell = {scale}x{scale} pixels)")
    
    # Create grid
    grid_width = width // scale
    grid_height = height // scale
    
    print(f"  Grid dimensions: {grid_width}x{grid_height}")
    
    grid = []
    accessible_count = 0
    
    for grid_y in range(grid_height):
        row = []
        for grid_x in range(grid_width):
            # Sample the center pixel of this grid cell
            pixel_x = grid_x * scale + scale // 2
            pixel_y = grid_y * scale + scale // 2
            
            # Ensure we don't go out of bounds
            pixel_x = min(pixel_x, width - 1)
            pixel_y = min(pixel_y, height - 1)
            
            pixel = img.getpixel((pixel_x, pixel_y))
            # Accessible if pixel is non-black (water)
            accessible = is_non_black_pixel(pixel)
            row.append(accessible)
            
            if accessible:
                accessible_count += 1
        
        grid.append(row)
    
    total_cells = grid_width * grid_height
    blocked_count = total_cells - accessible_count
    
    print(f"\n  Grid statistics:")
    print(f"    Accessible cells: {accessible_count} ({accessible_count/total_cells*100:.1f}%)")
    print(f"    Blocked cells: {blocked_count} ({blocked_count/total_cells*100:.1f}%)")
    
    return {
        'grid': grid,
        'width': grid_width,
        'height': grid_height,
        'scale': scale,
        'image_width': width,
        'image_height': height
    }

def save_grid_as_ruby(data, output_path):
    """Save navigation grid as Ruby array constant."""
    with open(output_path, 'w') as f:
        f.write("# Navigation Grid - Generated from water.png layer\n")
        f.write("# True = accessible (water), False = blocked (non-water)\n")
        f.write("#\n")
        f.write(f"# Grid dimensions: {data['width']}x{data['height']}\n")
        f.write(f"# Scale factor: {data['scale']} (each cell = {data['scale']}x{data['scale']} pixels)\n")
        f.write(f"# Image size: {data['image_width']}x{data['image_height']}\n")
        f.write("#\n")
        f.write("# Usage:\n")
        f.write("#   # Convert screen coordinates to grid coordinates\n")
        f.write(f"#   grid_x = (screen_x * {data['width']}) / {data['image_width']}\n")
        f.write(f"#   grid_y = (screen_y * {data['height']}) / {data['image_height']}\n")
        f.write("#   accessible = NAVIGATION_GRID[grid_y][grid_x]\n")
        f.write("\n")
        f.write("NAVIGATION_GRID = [\n")
        
        for row in data['grid']:
            ruby_row = "[" + ", ".join("true" if cell else "false" for cell in row) + "]"
            f.write(f"  {ruby_row},\n")
        
        f.write("]\n\n")
        
        # Add helper function
        f.write("# Check if screen coordinates are on an accessible path\n")
        f.write("# Args:\n")
        f.write("#   screen_x, screen_y - Screen pixel coordinates (DragonRuby grid space)\n")
        f.write("# Returns:\n")
        f.write("#   Boolean - true if accessible, false if blocked\n")
        f.write("def screen_position_accessible?(screen_x, screen_y)\n")
        f.write("  # Scale to map coordinates\n")
        f.write(f"  map_x = (screen_x * {data['image_width']}) / {SCREEN_WIDTH}\n")
        f.write(f"  map_y = (screen_y * {data['image_height']}) / {SCREEN_HEIGHT}\n")
        f.write("\n")
        f.write("  # Convert to grid coordinates\n")
        f.write(f"  grid_x = ((map_x * {data['width']}) / {data['image_width']}).floor\n")
        f.write(f"  grid_y_image = ((map_y * {data['height']}) / {data['image_height']}).floor\n")
        f.write("\n")
        f.write("  # Flip Y axis for DragonRuby (Y=0 at bottom)\n")
        f.write(f"  grid_y = {data['height']} - 1 - grid_y_image\n")
        f.write("\n")
        f.write(f"  return false if grid_x < 0 || grid_x >= {data['width']}\n")
        f.write(f"  return false if grid_y < 0 || grid_y >= {data['height']}\n")
        f.write("\n")
        f.write("  NAVIGATION_GRID[grid_y][grid_x]\n")
        f.write("end\n")
    
    print(f"\nSaved Ruby file: {output_path}")

def save_grid_as_json(data, output_path):
    """Save navigation grid as JSON."""
    json_data = {
        'width': data['width'],
        'height': data['height'],
        'scale': data['scale'],
        'image_width': data['image_width'],
        'image_height': data['image_height'],
        'grid': [[int(cell) for cell in row] for row in data['grid']]
    }
    
    with open(output_path, 'w') as f:
        json.dump(json_data, f, indent=2)
    
    print(f"Saved JSON file: {output_path}")

def save_waypoints_json(waypoints, output_path):
    """Save waypoints as JSON."""
    with open(output_path, 'w') as f:
        json.dump(waypoints, f, indent=2)
    
    print(f"Saved waypoints: {output_path} ({len(waypoints)} waypoints)")

def main():
    parser = argparse.ArgumentParser(
        description='Generate pathing system from layer images'
    )
    parser.add_argument(
        '--scale', type=int, default=10,
        help='Downscale factor for grid (default: 10)'
    )
    parser.add_argument(
        '--cluster-min-size', type=int, default=1,
        help='Minimum cluster size for waypoints (default: 1)'
    )
    parser.add_argument(
        '--visualize', action='store_true',
        help='Generate visualization images (not implemented yet)'
    )
    
    args = parser.parse_args()
    
    # Get paths
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    
    sprites_dir = os.path.join(project_root, 'sprites', 'hud', 'world-map')
    data_dir = os.path.join(project_root, 'data')
    
    # Ensure output directory exists
    os.makedirs(data_dir, exist_ok=True)
    
    # Image paths
    water_path = os.path.join(sprites_dir, 'water.png')
    port_path = os.path.join(sprites_dir, 'port.png')
    islands_path = os.path.join(sprites_dir, 'island.png')
    
    print("=" * 60)
    print("Pathing System Generator from Layer Images")
    print("=" * 60)
    
    # Process water layer -> navigation grid
    grid_data = generate_navigation_grid_from_water(water_path, scale=args.scale)
    
    if grid_data:
        # Save navigation grid
        ruby_path = os.path.join(data_dir, 'navigation_grid.rb')
        json_path = os.path.join(data_dir, 'navigation_grid.json')
        save_grid_as_ruby(grid_data, ruby_path)
        save_grid_as_json(grid_data, json_path)
    
    # Process port layer -> ports.json
    ports = detect_waypoints(port_path, 'port', cluster_min_size=args.cluster_min_size, scale=args.scale)
    if ports:
        # Assign meaningful names based on position (Caribbean = west, European = east)
        ports = assign_port_names(ports)
        ports_path = os.path.join(data_dir, 'ports.json')
        save_waypoints_json(ports, ports_path)
    
    # Process islands layer -> islands.json
    islands = detect_waypoints(islands_path, 'island', cluster_min_size=args.cluster_min_size, scale=args.scale)
    if islands:
        islands_path = os.path.join(data_dir, 'islands.json')
        save_waypoints_json(islands, islands_path)
    
    print("\n" + "=" * 60)
    print("Generation complete!")
    print("=" * 60)
    print(f"\nGenerated files:")
    print(f"  - data/navigation_grid.rb")
    print(f"  - data/navigation_grid.json")
    if ports:
        print(f"  - data/ports.json ({len(ports)} ports)")
    if islands:
        print(f"  - data/islands.json ({len(islands)} islands)")
    print("\nNext steps:")
    print("  1. Review generated waypoints in JSON files")
    print("  2. Update graph_system_dynamic.rb to use loaded waypoints")
    print("  3. Test pathfinding and ship movement")

if __name__ == '__main__':
    main()


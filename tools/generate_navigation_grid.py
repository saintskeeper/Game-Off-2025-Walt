#!/usr/bin/env python3
"""
World Map Navigation Grid Generator

Analyzes the world map image and creates a navigation grid that maps
which pixels/areas are accessible paths (ocean) vs blocked (land).

Usage:
    python generate_navigation_grid.py [--scale FACTOR] [--visualize]

Options:
    --scale FACTOR    Downscale factor (default: 10). Grid cell size in pixels.
                      Higher values = smaller grid, lower resolution.
    --visualize       Generate a visualization image of the grid.
    --output FORMAT   Output format: ruby, json, or both (default: both)
"""

from PIL import Image
import json
import argparse
import os

def analyze_pixel_colors(image_path):
    """Load image and identify unique colors with their counts."""
    img = Image.open(image_path).convert('RGB')
    pixels = img.getdata()

    color_counts = {}
    for pixel in pixels:
        color_counts[pixel] = color_counts.get(pixel, 0) + 1

    # Sort by frequency
    sorted_colors = sorted(color_counts.items(), key=lambda x: x[1], reverse=True)

    print("\nMost common colors in image:")
    for i, (color, count) in enumerate(sorted_colors[:10]):
        print(f"  {i+1}. RGB{color} - {count} pixels ({count/len(pixels)*100:.1f}%)")

    return img, sorted_colors

def classify_pixel(pixel, ocean_color, land_color, edge_color, tolerance=30):
    """Classify a pixel as ocean, land, edge, or unknown."""
    def color_distance(c1, c2):
        return sum((a - b) ** 2 for a, b in zip(c1, c2)) ** 0.5

    distances = {
        'ocean': color_distance(pixel, ocean_color),
        'land': color_distance(pixel, land_color),
        'edge': color_distance(pixel, edge_color)
    }

    min_type = min(distances, key=distances.get)

    if distances[min_type] <= tolerance:
        return min_type
    return 'unknown'

def flood_fill_connected_component(grid, start_x, start_y):
    """
    Find all cells in the connected component containing the start position.
    Uses flood fill algorithm.

    Args:
        grid: 2D boolean array
        start_x, start_y: Starting position

    Returns:
        Set of (x, y) tuples representing all connected cells
    """
    if not grid[start_y][start_x]:
        return set()

    height = len(grid)
    width = len(grid[0])
    visited = set()
    stack = [(start_x, start_y)]

    while stack:
        x, y = stack.pop()

        if (x, y) in visited:
            continue

        if x < 0 or x >= width or y < 0 or y >= height:
            continue

        if not grid[y][x]:
            continue

        visited.add((x, y))

        # Check 4-connected neighbors (up, down, left, right)
        stack.extend([(x+1, y), (x-1, y), (x, y+1), (x, y-1)])

    return visited

def find_largest_connected_component(grid):
    """
    Find the largest connected component of accessible cells.

    Args:
        grid: 2D boolean array (True = accessible)

    Returns:
        Set of (x, y) tuples representing the largest connected region
    """
    height = len(grid)
    width = len(grid[0])

    all_visited = set()
    components = []

    # Find all connected components
    for y in range(height):
        for x in range(width):
            if grid[y][x] and (x, y) not in all_visited:
                component = flood_fill_connected_component(grid, x, y)
                all_visited.update(component)
                components.append(component)

    if not components:
        return set()

    # Return the largest component
    largest = max(components, key=len)

    print(f"\nConnectivity analysis:")
    print(f"  Found {len(components)} separate ocean regions")
    print(f"  Largest region: {len(largest)} cells")
    if len(components) > 1:
        print(f"  Removed {len(components) - 1} disconnected regions with {len(all_visited) - len(largest)} cells")

    return largest

def generate_navigation_grid(image_path, scale=10, ocean_color=None, land_color=None, edge_color=None):
    """
    Generate a navigation grid from the world map image.

    Args:
        image_path: Path to the world map image
        scale: Downscale factor - each grid cell represents scale x scale pixels
        ocean_color: RGB tuple for ocean color (auto-detected if None)
        land_color: RGB tuple for land color (auto-detected if None)
        edge_color: RGB tuple for edge color (auto-detected if None)

    Returns:
        dict with grid data and metadata
    """
    img, sorted_colors = analyze_pixel_colors(image_path)
    width, height = img.size

    # Auto-detect colors if not provided
    # Assumptions: Pink = ocean (most common), Green = land, Black = edges
    if not ocean_color:
        # Find pinkish color (high R, medium-high G, medium-high B)
        for color, _ in sorted_colors:
            r, g, b = color
            if r > 150 and g > 100 and b > 150:  # Pinkish
                ocean_color = color
                break
        if not ocean_color:
            ocean_color = sorted_colors[0][0]  # Fallback to most common

    if not land_color:
        # Find greenish color (low R, high G, low B)
        for color, _ in sorted_colors:
            r, g, b = color
            if g > r and g > b and g > 100:  # Greenish
                land_color = color
                break
        if not land_color:
            land_color = sorted_colors[1][0] if len(sorted_colors) > 1 else (0, 255, 0)

    if not edge_color:
        # Find dark/black color (low R, G, B)
        for color, _ in sorted_colors:
            r, g, b = color
            if r < 50 and g < 50 and b < 50:  # Dark
                edge_color = color
                break
        if not edge_color:
            edge_color = (0, 0, 0)

    print(f"\nUsing colors:")
    print(f"  Ocean (accessible): RGB{ocean_color}")
    print(f"  Land (blocked): RGB{land_color}")
    print(f"  Edge (blocked): RGB{edge_color}")

    # Create grid
    grid_width = width // scale
    grid_height = height // scale

    print(f"\nGenerating {grid_width}x{grid_height} navigation grid...")
    print(f"  Image size: {width}x{height}")
    print(f"  Scale factor: {scale} (each cell = {scale}x{scale} pixels)")

    grid = []
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
            cell_type = classify_pixel(pixel, ocean_color, land_color, edge_color)

            # Convert to boolean: True = accessible (ocean), False = blocked (land/edge)
            accessible = (cell_type == 'ocean')
            row.append(accessible)

        grid.append(row)

    # Find largest connected component to ensure all paths are connected
    largest_component = find_largest_connected_component(grid)

    # Update grid to only include the largest connected region
    for y in range(grid_height):
        for x in range(grid_width):
            if grid[y][x] and (x, y) not in largest_component:
                grid[y][x] = False  # Mark disconnected ocean as blocked

    # Count accessible vs blocked cells (after connectivity filtering)
    total_cells = grid_width * grid_height
    accessible_count = sum(sum(row) for row in grid)
    blocked_count = total_cells - accessible_count

    print(f"\nFinal grid statistics:")
    print(f"  Accessible cells: {accessible_count} ({accessible_count/total_cells*100:.1f}%)")
    print(f"  Blocked cells: {blocked_count} ({blocked_count/total_cells*100:.1f}%)")

    return {
        'grid': grid,
        'width': grid_width,
        'height': grid_height,
        'scale': scale,
        'image_width': width,
        'image_height': height,
        'colors': {
            'ocean': ocean_color,
            'land': land_color,
            'edge': edge_color
        }
    }

def save_grid_as_ruby(data, output_path):
    """Save grid as Ruby array constant."""
    with open(output_path, 'w') as f:
        f.write("# Navigation Grid - Generated from world map image\n")
        f.write("# True = accessible (ocean), False = blocked (land/edge)\n")
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
            # Convert booleans to Ruby syntax
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
        f.write(f"  grid_x = ((screen_x * {data['width']}) / {data['image_width']}).floor\n")
        f.write(f"  grid_y = ((screen_y * {data['height']}) / {data['image_height']}).floor\n")
        f.write("\n")
        f.write(f"  return false if grid_x < 0 || grid_x >= {data['width']}\n")
        f.write(f"  return false if grid_y < 0 || grid_y >= {data['height']}\n")
        f.write("\n")
        f.write("  NAVIGATION_GRID[grid_y][grid_x]\n")
        f.write("end\n")

    print(f"\nSaved Ruby file: {output_path}")

def save_grid_as_json(data, output_path):
    """Save grid as JSON."""
    # Convert boolean numpy/list to JSON-serializable format
    json_data = {
        'width': data['width'],
        'height': data['height'],
        'scale': data['scale'],
        'image_width': data['image_width'],
        'image_height': data['image_height'],
        'colors': {
            'ocean': list(data['colors']['ocean']),
            'land': list(data['colors']['land']),
            'edge': list(data['colors']['edge'])
        },
        'grid': [[int(cell) for cell in row] for row in data['grid']]  # Convert bool to 0/1
    }

    with open(output_path, 'w') as f:
        json.dump(json_data, f, indent=2)

    print(f"Saved JSON file: {output_path}")

def visualize_grid(data, output_path):
    """Generate a visualization image of the navigation grid."""
    width, height = data['width'], data['height']

    # Create image (scale up for visibility)
    viz_scale = max(1, 800 // width)  # Scale to ~800px wide
    img = Image.new('RGB', (width * viz_scale, height * viz_scale))
    pixels = img.load()

    # Draw grid
    for y in range(height):
        for x in range(width):
            color = (100, 150, 255) if data['grid'][y][x] else (50, 50, 50)

            # Fill the scaled cell
            for dy in range(viz_scale):
                for dx in range(viz_scale):
                    pixels[x * viz_scale + dx, y * viz_scale + dy] = color

    img.save(output_path)
    print(f"Saved visualization: {output_path}")

def main():
    parser = argparse.ArgumentParser(description='Generate navigation grid from world map image')
    parser.add_argument('--scale', type=int, default=10, help='Downscale factor (default: 10)')
    parser.add_argument('--visualize', action='store_true', help='Generate visualization image')
    parser.add_argument('--output', choices=['ruby', 'json', 'both'], default='both',
                        help='Output format (default: both)')

    args = parser.parse_args()

    # Get paths
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    image_path = os.path.join(project_root, 'sprites/hud/world-map/world-map_export-nodithering.png')
    output_dir = os.path.join(project_root, 'data')

    # Ensure output directory exists
    os.makedirs(output_dir, exist_ok=True)

    print(f"Analyzing world map: {image_path}")

    # Generate grid
    data = generate_navigation_grid(image_path, scale=args.scale)

    # Save outputs
    if args.output in ['ruby', 'both']:
        ruby_path = os.path.join(output_dir, 'navigation_grid.rb')
        save_grid_as_ruby(data, ruby_path)

    if args.output in ['json', 'both']:
        json_path = os.path.join(output_dir, 'navigation_grid.json')
        save_grid_as_json(data, json_path)

    if args.visualize:
        viz_path = os.path.join(output_dir, 'navigation_grid_visualization.png')
        visualize_grid(data, viz_path)

    print("\nDone! You can now:")
    print("  1. Require the navigation grid in your game: require 'data/navigation_grid.rb'")
    print("  2. Use screen_position_accessible?(x, y) to check if coordinates are valid")
    print("  3. Use NAVIGATION_GRID directly for pathfinding algorithms")

if __name__ == '__main__':
    main()

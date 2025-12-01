# Pathing System Rebuild Plan

## Overview
Rebuild the navigation and pathfinding system to use the new layer images:
- `water.png` - Defines accessible paths (replaces hardcoded navigation grid)
- `islands.png` - Defines island waypoint locations
- `port.png` - Defines port waypoint locations

## Current System Architecture

### Components
1. **`navigation_grid.rb`** - Hardcoded 30x14 boolean grid
2. **`pathfinding_system.rb`** - A* pathfinding using the grid
3. **`graph_system_dynamic.rb`** - Builds graph with 3 hardcoded waypoints
4. **`generate_navigation_grid.py`** - Python tool to analyze world map

### Current Flow
1. Hardcoded `NAVIGATION_GRID` defines accessible cells
2. Hardcoded `KEY_WAYPOINTS` defines 3 locations (caribbean_port, mid_atlantic, european_port)
3. Graph system finds paths between waypoints using A*
4. Ship moves along graph edges

## New System Architecture

### Phase 1: Image Processing Tool
**File**: `mygame/tools/generate_pathing_from_layers.py`

**Purpose**: Parse layer images and generate data files

**Functionality**:
1. **Load and analyze `water.png`**:
   - Convert to navigation grid (boolean: water = accessible, non-water = blocked)
   - Support configurable scale factor (default: 10 pixels per grid cell)
   - Generate `navigation_grid.rb` and `navigation_grid.json`

2. **Load and analyze `port.png`**:
   - Detect all port locations (non-black pixels)
   - Group nearby pixels into port clusters (using flood fill or distance-based clustering)
   - Extract center coordinates for each port
   - Generate `ports.json` with array of port locations

3. **Load and analyze `islands.png`**:
   - Detect all island locations (non-black pixels)
   - Group nearby pixels into island clusters
   - Extract center coordinates for each island
   - Generate `islands.json` with array of island locations

4. **Validation**:
   - Ensure all ports/islands are on accessible water cells
   - If not, find nearest accessible position
   - Warn about disconnected regions

**Output Files**:
- `mygame/data/navigation_grid.rb` (updated)
- `mygame/data/navigation_grid.json` (updated)
- `mygame/data/ports.json` (new)
- `mygame/data/islands.json` (new)

### Phase 2: Update Navigation Grid System
**File**: `mygame/data/navigation_grid.rb`

**Changes**:
- Keep existing structure for compatibility
- Add comment noting it's generated from `water.png`
- Ensure grid dimensions match image dimensions

**File**: `mygame/app/pathfinding_system.rb`

**Changes**:
- No changes needed (already uses `NAVIGATION_GRID`)
- Verify coordinate conversion works with new grid dimensions

### Phase 3: Update Graph System
**File**: `mygame/app/graph_system_dynamic.rb`

**Changes**:
1. **Load waypoints from data files**:
   ```ruby
   # Load ports and islands from generated JSON files
   ports = load_ports_data()
   islands = load_islands_data()
   ```

2. **Replace hardcoded `KEY_WAYPOINTS`**:
   - Generate waypoints dynamically from ports and islands
   - Assign unique IDs (e.g., `:port_0`, `:port_1`, `:island_0`, etc.)
   - Store metadata (type: :port or :island, name, etc.)

3. **Update `initialize_waypoint_nodes`**:
   - Load all ports and islands
   - Validate positions are accessible (adjust if needed)
   - Create nodes for each port and island

4. **Update `build_dynamic_graph`**:
   - **Option A (Full Mesh)**: Connect all ports/islands to all other ports/islands
     - Pros: Maximum routing flexibility
     - Cons: Many edges, may be slow
   - **Option B (Smart Connections)**: Only connect nearby ports/islands
     - Use distance threshold (e.g., max 500 pixels)
     - Only create edges if pathfinding succeeds
     - Pros: Fewer edges, faster
     - Cons: May miss some valid routes
   - **Option C (Hybrid)**: Connect all ports to all ports, all islands to nearby ports
     - Ports are major hubs (connect to all other ports)
     - Islands are minor waypoints (connect to nearby ports/islands)
     - Pros: Realistic routing, manageable edge count

5. **Determine start/end nodes**:
   - Start: Leftmost port (lowest x coordinate)
   - End: Rightmost port (highest x coordinate)
   - Or: Allow configuration in data files

### Phase 4: Data Loading System
**File**: `mygame/app/data_loader.rb` (new)

**Purpose**: Centralized data loading from JSON files

**Functionality**:
```ruby
def load_ports_data
  # Load ports.json and return array of port hashes
  # Each port: { id: :port_0, position: { x:, y: }, type: :port, metadata: {...} }
end

def load_islands_data
  # Load islands.json and return array of island hashes
  # Each island: { id: :island_0, position: { x:, y: }, type: :island, metadata: {...} }
end
```

### Phase 5: Testing and Validation
**File**: `mygame/test_pathing_system.rb` (new or update existing)

**Tests**:
1. Verify all ports/islands are accessible
2. Verify pathfinding works between all connected waypoints
3. Verify graph is fully connected (all nodes reachable)
4. Visualize graph structure (nodes and edges)
5. Test ship movement along generated paths

## Implementation Steps

### Step 1: Create Image Processing Tool
1. Create `generate_pathing_from_layers.py`
2. Implement water.png → navigation grid conversion
3. Implement port.png → ports.json conversion
4. Implement islands.png → islands.json conversion
5. Test with current layer images

### Step 2: Generate Initial Data
1. Run tool to generate data files
2. Verify output files are correct
3. Check that ports/islands are on accessible water

### Step 3: Update Graph System
1. Create `data_loader.rb`
2. Update `graph_system_dynamic.rb` to use loaded data
3. Implement connection strategy (recommend Option C: Hybrid)
4. Test graph generation

### Step 4: Integration Testing
1. Verify ship can move along all edges
2. Verify pathfinding works correctly
3. Verify rendering displays all nodes/edges
4. Test gameplay flow

### Step 5: Refinement
1. Optimize connection strategy if needed
2. Add metadata to ports/islands (names, descriptions)
3. Fine-tune waypoint positions if needed
4. Update documentation

## Technical Considerations

### Image Processing
- **Color Detection**: Use threshold-based detection (non-black = feature)
- **Clustering**: Use flood fill or distance-based clustering to group nearby pixels
- **Coordinate Conversion**: Map image coordinates → screen coordinates
- **Grid Scale**: Maintain current scale (10 pixels per grid cell) or make configurable

### Graph Generation
- **Node IDs**: Use descriptive IDs (`:port_caribbean`, `:island_mid_atlantic`) or sequential (`:port_0`, `:port_1`)
- **Edge Generation**: Create bidirectional edges (A→B and B→A) with reversed paths
- **Path Validation**: Only create edges if pathfinding succeeds
- **Performance**: Limit edge generation to avoid combinatorial explosion

### Coordinate Systems
- **Image Coordinates**: (0,0) at top-left, matches image pixels
- **Screen Coordinates**: (0,0) at bottom-left, DragonRuby standard
- **Grid Coordinates**: Scaled down version of image coordinates
- **Conversion**: Must handle Y-axis flip between image and screen

## File Structure

```
mygame/
├── data/
│   ├── navigation_grid.rb      (generated from water.png)
│   ├── navigation_grid.json    (generated from water.png)
│   ├── ports.json               (generated from port.png)
│   └── islands.json             (generated from islands.png)
├── tools/
│   └── generate_pathing_from_layers.py  (new)
├── app/
│   ├── data_loader.rb           (new)
│   ├── graph_system_dynamic.rb  (updated)
│   ├── pathfinding_system.rb    (no changes)
│   └── navigation_grid.rb       (no changes)
└── docs/
    └── pathing-system-rebuild-plan.md  (this file)
```

## Success Criteria

1. ✅ Navigation grid generated from `water.png`
2. ✅ All ports detected from `port.png`
3. ✅ All islands detected from `islands.png`
4. ✅ Graph automatically generated with all waypoints
5. ✅ Ship can navigate between all connected waypoints
6. ✅ Pathfinding works correctly on new grid
7. ✅ System is maintainable (regenerate data when images change)

## Future Enhancements

1. **Dynamic Regeneration**: Regenerate data files when layer images change
2. **Editor Integration**: Visual editor to place/edit ports and islands
3. **Metadata System**: Add names, descriptions, gameplay properties to waypoints
4. **Route Optimization**: Pre-compute common routes for performance
5. **Multiple Path Options**: Store multiple path options between waypoints


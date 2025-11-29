### Core Concepts
# - Ship moves along a circular path using polar coordinates
# - `angle` (radians) determines position on circle
# - Convert polar to cartesian: `x = center_x + radius * cos(angle)`
# - Loop completes when ship crosses the 0/2π boundary

### Algorithm
# ```
# Each tick:
#   1. Store previous_angle = ship_angle
#   2. Increment ship_angle by ship_speed
#   3. If ship_angle >= 2π (full circle):
#      - Reset to 0 (or subtract 2π)
#      - Trigger on_loop_complete event
#   4. Calculate ship x,y from angle
#   5. Check which slot the ship is passing over
# ```

### Slot Detection
# ```
# 12 slots around circle = 2π/12 = 0.523 radians per slot
# slot_index = (ship_angle / (2π / 12)).floor
# When slot_index changes, ship has entered a new slot
# ```

### Key Code Pattern
# Constants for loop geometry
LOOP_CENTER_X = 640
LOOP_CENTER_Y = 360
LOOP_RADIUS = 200
SLOT_COUNT = 12
TWO_PI = Math::PI * 2

# Updates ship position along circular path and triggers events
# Called each tick to advance the ship and detect slot/loop completion
def update_ship(args)
	state = args.state
	prev_slot = current_slot_index(state.ship_angle)
	state.ship_angle += state.ship_speed

	# Check for loop completion (ship crossed 0/2π boundary)
	if state.ship_angle >= TWO_PI
		state.ship_angle -= TWO_PI
		on_loop_complete(args)
	end

	# Check if we entered a new slot (slot index changed)
	new_slot = current_slot_index(state.ship_angle)
	if new_slot != prev_slot && new_slot >= 0
		on_enter_slot(args, new_slot)
	end
end

# Calculates which slot (0-11) the ship is currently in based on angle
# Uses modulo to handle angle wrapping
def current_slot_index(angle)
	(angle / (TWO_PI / SLOT_COUNT)).floor % SLOT_COUNT
end

# Converts polar coordinates (angle) to cartesian (x, y) for ship rendering
# Returns hash with :x and :y keys for ship position on screen
def ship_position(angle)
	{
		x: LOOP_CENTER_X + LOOP_RADIUS * Math.cos(angle),
		y: LOOP_CENTER_Y + LOOP_RADIUS * Math.sin(angle)
	}
end

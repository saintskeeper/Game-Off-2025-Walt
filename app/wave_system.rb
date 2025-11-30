# Wave System - Handles random tile destruction events
#
# Core Concepts:
# - 15% chance each loop completion triggers a wave
# - Wave destroys one random tile from any edge in the graph
# - Simple visual feedback flag for rendering (wave_active)
#
# Integration:
# - Called by meter_system.rb when a loop completes (on_loop_complete)
# - Sets wave_active flag that renderer can use for visual effects

# Probability of a wave occurring after each loop completion (percentage)
WAVE_CHANCE = 15  # 15% chance

# Triggers a wave event that destroys a random tile (if conditions are met)
# Called after each loop completion to potentially remove a tile
# Algorithm:
#   1. Roll random 0-100
#   2. If roll < WAVE_CHANCE (15%):
#      - Find all occupied slots across all edges
#      - Pick random one
#      - Set that slot to nil (destroy tile)
#      - Set wave_active flag for visual feedback (30 frames)
# Args:
#   args - DragonRuby args object containing state
def maybe_trigger_wave(args)
  # Roll for wave chance (0-99, so < 15 means 15% chance)
  return if rand(100) >= WAVE_CHANCE

  # Find all occupied slots across all edges
  occupied_slots = []
  args.state.path_edges.each do |edge|
    edge[:tiles].each_with_index do |tile, slot_index|
      if tile
        occupied_slots << { edge: edge, slot_index: slot_index }
      end
    end
  end

  # If no tiles exist, nothing to destroy
  return if occupied_slots.empty?

  # Destroy a random tile by setting its slot to nil
  target = occupied_slots.sample
  target[:edge][:tiles][target[:slot_index]] = nil

  # Invalidate map render target to force rebuild without destroyed tile
  args.state.map_render_target_built = false

  # Set visual feedback flag (30 frames = ~0.5 seconds at 60fps)
  # Renderer can use this to show wave effect
  args.state.wave_active = 30
end


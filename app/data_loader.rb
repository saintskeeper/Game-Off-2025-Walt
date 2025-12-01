# Data Loader - Loads waypoint data from JSON files
#
# Core Concepts:
# - Loads ports and islands from generated JSON files
# - Converts JSON data to Ruby hash format for use in graph system
# - Handles missing files gracefully (returns empty arrays)
# - Provides consistent data structure for waypoints

# JSON parsing: DragonRuby has built-in JSON support via GTK.parse_json
# Standard Ruby would need 'require json', but DragonRuby doesn't need it
# We'll use GTK.parse_json when available, or fall back to JSON.parse if the gem is available

# Helper to check if a constant is defined (mruby-compatible)
# In mruby, defined? keyword may not be available, so we use begin/rescue
# Args:
#   constant_name - Symbol or String name of the constant to check
# Returns:
#   true if constant exists, false otherwise
def constant_defined?(constant_name)
  begin
    # Try to access the constant - if it exists, this won't raise NameError
    Object.const_get(constant_name)
    true
  rescue NameError
    false
  end
end

# Helper to read file (works in both DragonRuby and standard Ruby)
# Args:
#   file_path - Path to file
# Returns:
#   String content or nil if file doesn't exist
def read_data_file(file_path)
  # Try DragonRuby's $gtk.read_file first (if available)
  # $gtk is the global DragonRuby instance with read_file as an instance method
  if $gtk && $gtk.respond_to?(:read_file)
    begin
      content = $gtk.read_file(file_path)
      return content if content && !content.empty?
    rescue => e
      # Fall back to File.read
    end
  end

  # Fall back to standard Ruby File.read
  begin
    return File.read(file_path) if File.exist?(file_path)
  rescue => e
    # File doesn't exist or can't be read
  end

  nil
end

# Parse JSON content (works in both DragonRuby and standard Ruby)
# Args:
#   json_content - JSON string
# Returns:
#   Parsed hash/array or nil on error
def parse_json_content(json_content)
  # Try DragonRuby's native JSON parser first (always available in DragonRuby)
  # $gtk is the global DragonRuby instance with parse_json as an instance method
  if $gtk && $gtk.respond_to?(:parse_json)
    begin
      return $gtk.parse_json(json_content)
    rescue => e
      puts "[DATA] $gtk.parse_json failed: #{e.message}"
    end
  end

  # Fall back to standard JSON.parse (for standard Ruby, if JSON gem is available)
  begin
    if constant_defined?(:JSON) && JSON.respond_to?(:parse)
      return JSON.parse(json_content)
    end
  rescue => e
    puts "[DATA] JSON.parse failed: #{e.message}"
  end

  nil
end

# Load ports from ports.json
# Returns:
#   Array of port hashes with :id, :position, :type, :metadata keys
#   Returns empty array if file doesn't exist or parsing fails
def load_ports_data
  # Try multiple possible paths
  possible_paths = ['data/ports.json', 'mygame/data/ports.json']

  ports_data = nil
  used_path = nil

  possible_paths.each do |ports_path|
    begin
      # Try reading file and parsing JSON
      json_content = read_data_file(ports_path)

      if json_content
        parsed = parse_json_content(json_content)
        if parsed
          ports_data = parsed
          used_path = ports_path
          break
        end
      end
    rescue => e
      # Try next path
    end
  end

  if ports_data && used_path
    # Convert string keys to symbols and ensure consistent structure
    ports = ports_data.map do |port|
      {
        id: port['id'].to_sym,
        position: {
          x: port['position']['x'],
          y: port['position']['y']
        },
        type: port['type'].to_sym,
        metadata: port['metadata'] || {},
        grid_squares: (port['grid_squares'] || []).map do |square|
          { x: square['x'], y: square['y'] }
        end
      }
    end

    puts "[DATA] Loaded #{ports.length} ports from #{used_path}"
    ports
  else
    puts "[DATA] WARNING: ports.json not found in any of these paths: #{possible_paths.join(', ')}"
    []
  end
rescue => e
  puts "[DATA] ERROR loading ports: #{e.message}"
  puts "[DATA] Backtrace: #{e.backtrace.first(3).join("\n")}"
  []
end

# Load islands from islands.json
# Returns:
#   Array of island hashes with :id, :position, :type, :metadata keys
#   Returns empty array if file doesn't exist or parsing fails
def load_islands_data
  # Try multiple possible paths
  possible_paths = ['data/islands.json', 'mygame/data/islands.json']

  islands_data = nil
  used_path = nil

  possible_paths.each do |islands_path|
    begin
      # Try reading file and parsing JSON
      json_content = read_data_file(islands_path)

      if json_content
        parsed = parse_json_content(json_content)
        if parsed
          islands_data = parsed
          used_path = islands_path
          break
        end
      end
    rescue => e
      # Try next path
    end
  end

  if islands_data && used_path
    # Convert string keys to symbols and ensure consistent structure
    islands = islands_data.map do |island|
      {
        id: island['id'].to_sym,
        position: {
          x: island['position']['x'],
          y: island['position']['y']
        },
        type: island['type'].to_sym,
        metadata: island['metadata'] || {},
        grid_squares: (island['grid_squares'] || []).map do |square|
          { x: square['x'], y: square['y'] }
        end
      }
    end

    puts "[DATA] Loaded #{islands.length} islands from #{used_path}"
    islands
  else
    # Don't warn for islands.json if it doesn't exist (it's optional)
    # puts "[DATA] WARNING: islands.json not found in any of these paths: #{possible_paths.join(', ')}"
    []
  end
rescue => e
  puts "[DATA] ERROR loading islands: #{e.message}"
  puts "[DATA] Backtrace: #{e.backtrace.first(3).join("\n")}"
  []
end

# Load all waypoints (ports + islands)
# Returns:
#   Array of all waypoint hashes
def load_all_waypoints
  ports = load_ports_data
  islands = load_islands_data
  ports + islands
end


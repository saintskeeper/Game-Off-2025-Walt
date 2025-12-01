#!/bin/bash
# Launcher script - regenerates pathing data then runs DragonRuby

cd "$(dirname "$0")"

echo "Regenerating pathing data..."
cd tools
source venv/bin/activate
python generate_pathing_from_layers.py --scale 3
cd ..

echo "Launching DragonRuby..."
cd ..
./dragonruby mygame

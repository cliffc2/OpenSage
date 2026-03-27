#!/bin/bash

# OpenSage Web UI launcher
# Run from the opensage directory

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UV_BIN="$HOME/.local/bin/uv"

# Default values
AGENT="${1:-examples/agents/my_ollama_agent}"
PORT="${2:-8000}"

# Check if uv is installed
if [ ! -x "$UV_BIN" ]; then
    echo "Error: uv not found at $UV_BIN"
    echo "Install uv with: curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi

# Check if agent directory exists
if [ ! -d "$SCRIPT_DIR/$AGENT" ]; then
    echo "Error: Agent directory not found: $AGENT"
    echo ""
    echo "Available agents:"
    ls -1 "$SCRIPT_DIR/examples/agents/" | sed 's/^/  /'
    exit 1
fi

echo "Starting OpenSage Web UI..."
echo "Agent: $AGENT"
echo "Port: $PORT"
echo ""
echo "Access at: http://localhost:$PORT"
echo "Press Ctrl+C to stop"
echo ""

cd "$SCRIPT_DIR"
$UV_BIN run opensage web --agent "$AGENT" --port "$PORT"

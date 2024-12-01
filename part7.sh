# part7.sh
#!/bin/bash

# Create startup scripts
echo "Setting up startup scripts..."

# Create start script
cat > start.sh << 'EOF'
#!/bin/bash

# Kill any existing processes
pkill -f "uvicorn main:app" || true
pkill -f "next dev" || true

# Initialize variables
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Set up Python environment
source venv/bin/activate

# Start backend
echo "Starting backend server..."
cd backend
PYTHONPATH=$SCRIPT_DIR/backend python3 -m uvicorn main:app --host 127.0.0.1 --port 8000 --reload &
BACKEND_PID=$!
cd ..

# Wait for backend to start
echo -n "Waiting for backend"
MAX_ATTEMPTS=30
ATTEMPTS=0

while ! curl -s http://127.0.0.1:8000/health > /dev/null && [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
    echo -n "."
    sleep 1
    ATTEMPTS=$((ATTEMPTS + 1))
done

if [ $ATTEMPTS -eq $MAX_ATTEMPTS ]; then
    echo " Failed to start backend!"
    kill $BACKEND_PID
    exit 1
fi

echo " Ready!"

# Start frontend
echo "Starting frontend..."
cd frontend
npm run dev &
FRONTEND_PID=$!

echo "
Demo is running!
Backend: http://127.0.0.1:8000
Frontend: http://localhost:3000
"

# Handle shutdown
trap 'kill $BACKEND_PID $FRONTEND_PID 2>/dev/null; exit 0' INT TERM

# Wait for processes
while kill -0 $BACKEND_PID >/dev/null 2>&1 && kill -0 $FRONTEND_PID >/dev/null 2>&1; do
    sleep 1
done

# If we get here, one of the processes died
echo "Error: A service has stopped unexpectedly"
kill $BACKEND_PID $FRONTEND_PID 2>/dev/null
EOF

chmod +x start.sh

# Create README
cat > README.md << 'EOF'
# Video Compression Demo

A demonstration comparing binary and ternary video compression methods.

## Requirements

- Python 3.8+
- Node.js 16+
- npm 7+
- macOS (optimized for Apple Silicon/Intel)

## Quick Start

1. Run the installation:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

2. Start the demo:
   ```bash
   ./start.sh
   ```

3. Open http://localhost:3000 in your browser

## Features

- Upload and process video files
- Real-time progress tracking
- Compare binary and ternary compression
- Detailed metrics and analysis
- Interactive user interface
- Side-by-side video comparison
- Synchronized playback controls

## Development

- Backend API: http://127.0.0.1:8000/docs
- Frontend: http://localhost:3000

## Troubleshooting

1. Video playback issues:
   - Ensure your browser supports H.264/AVC1 video codec
   - Check the browser console for detailed error messages
   - Try accessing the video URLs directly to verify server response

2. Server issues:
   - Check both frontend and backend logs
   - Ensure ports 3000 and 8000 are free
   - Try removing node_modules and reinstalling
   - Check Python virtual environment is active

3. Installation issues:
   - Make sure you have Python 3.8+ and Node.js 16+ installed
   - Run `brew doctor` to check Homebrew installation
   - Check pip and npm are up to date
EOF

# Create .gitignore
cat > .gitignore << 'EOF'
# Python
__pycache__/
*.py[cod]
*$py.class
venv/
.env

# Node
node_modules/
.next/
out/
.DS_Store
*.pem
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Project specific
data/uploads/*
data/outputs/*
data/analysis/*
!data/uploads/.gitkeep
!data/outputs/.gitkeep
!data/analysis/.gitkeep
logs/*
!logs/.gitkeep
EOF

# Create empty directories with .gitkeep
touch data/uploads/.gitkeep
touch data/outputs/.gitkeep
touch data/analysis/.gitkeep
touch logs/.gitkeep

# Create install script
cat > install.sh << 'EOF'
#!/bin/bash

# Run all installation parts
for script in part{1..7}.sh; do
    echo "Running $script..."
    bash "$script"
    if [ $? -ne 0 ]; then
        echo "Error in $script"
        exit 1
    fi
done

echo "Installation complete!"
echo "Run './start.sh' to launch the demo"
echo "Access the demo at http://localhost:3000"
EOF

chmod +x install.sh

echo "Installation scripts setup complete!"
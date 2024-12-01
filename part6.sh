# part6.sh
#!/bin/bash

# Create codec components
echo "Setting up codec components and analysis tools..."

mkdir -p backend/codec/utils
mkdir -p backend/tests/codec
mkdir -p backend/tests/data

# Create benchmark script
cat > backend/benchmark.py << 'EOF'
import time
import numpy as np
from pathlib import Path
from codec.utils import process_binary, process_ternary

def run_benchmark(video_path: str, output_dir: Path):
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Process with binary compression
    binary_output = output_dir / "binary_output.mp4"
    binary_start = time.time()
    binary_metrics = process_binary(video_path, str(binary_output))
    binary_time = time.time() - binary_start
    
    # Process with ternary compression
    ternary_output = output_dir / "ternary_output.mp4"
    ternary_start = time.time()
    ternary_metrics = process_ternary(video_path, str(ternary_output))
    ternary_time = time.time() - ternary_start
    
    print("\nBenchmark Results:")
    print("\nBinary Compression:")
    print(f"PSNR: {binary_metrics['psnr']:.2f} dB")
    print(f"Compression Ratio: {binary_metrics['compression_ratio']:.2%}")
    print(f"Processing Time: {binary_metrics['processing_time']:.2f} ms")
    
    print("\nTernary Compression:")
    print(f"PSNR: {ternary_metrics['psnr']:.2f} dB")
    print(f"Compression Ratio: {ternary_metrics['compression_ratio']:.2%}")
    print(f"Processing Time: {ternary_metrics['processing_time']:.2f} ms")

if __name__ == "__main__":
    import sys
    if len(sys.argv) != 2:
        print("Usage: python benchmark.py <video_path>")
        sys.exit(1)
    
    run_benchmark(sys.argv[1], Path("benchmark_results"))
EOF

# Create test files
cat > backend/tests/codec/test_codec.py << 'EOF'
import pytest
import numpy as np
from ...codec.utils import process_binary, process_ternary
import cv2

def test_binary_compression():
    # Create a test video file
    output_path = "test_binary.mp4"
    frame_size = (320, 240)
    fps = 30.0
    
    # Create a random test video
    frames = []
    for _ in range(30):  # 1 second of video
        frame = np.random.randint(0, 255, (*frame_size, 3), dtype=np.uint8)
        frames.append(frame)
    
    # Save test video
    fourcc = cv2.VideoWriter_fourcc('a', 'v', 'c', '1')
    out = cv2.VideoWriter('test_input.mp4', fourcc, fps, frame_size)
    for frame in frames:
        out.write(frame)
    out.release()
    
    # Test compression
    metrics = process_binary('test_input.mp4', output_path)
    
    assert metrics['psnr'] > 0
    assert 0 < metrics['compression_ratio'] <= 1.0
    assert metrics['processing_time'] > 0

def test_ternary_compression():
    # Similar test for ternary compression
    output_path = "test_ternary.mp4"
    frame_size = (320, 240)
    fps = 30.0
    
    # Create a random test video
    frames = []
    for _ in range(30):
        frame = np.random.randint(0, 255, (*frame_size, 3), dtype=np.uint8)
        frames.append(frame)
    
    # Save test video
    fourcc = cv2.VideoWriter_fourcc('a', 'v', 'c', '1')
    out = cv2.VideoWriter('test_input.mp4', fourcc, fps, frame_size)
    for frame in frames:
        out.write(frame)
    out.release()
    
    # Test compression
    metrics = process_ternary('test_input.mp4', output_path)
    
    assert metrics['psnr'] > 0
    assert 0 < metrics['compression_ratio'] <= 1.0
    assert metrics['processing_time'] > 0
EOF

echo "Codec components and analysis tools setup complete..."
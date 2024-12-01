# part1.sh
#!/bin/bash

echo "Setting up Enhanced Ternary Compression Demo..."

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Clean up any existing installation
rm -rf ternary-compression-demo
mkdir -p ternary-compression-demo
cd ternary-compression-demo || exit 1

# Create enhanced directory structure
mkdir -p backend/codec
mkdir -p frontend
mkdir -p data/{frames,uploads,temp,outputs,analysis}
mkdir -p logs

# Setup Python virtual environment
python3 -m venv venv
source venv/bin/activate

# Install enhanced backend dependencies
echo "Installing backend dependencies..."
pip install --upgrade pip
pip install wheel setuptools
pip install "fastapi[all]"
pip install "uvicorn[standard]"
pip install python-multipart
pip install numpy 
pip install opencv-python
pip install scikit-learn
pip install scikit-image
pip install aiofiles
pip install pytest
pip install python-jose[cryptography]
pip install Pillow
pip install matplotlib

# Verify installations
echo "Verifying package installation..."
python3 -c "
try:
    import cv2
    import numpy
    import sklearn.metrics
    from sklearn.metrics import mean_squared_error
    from skimage import metrics
    print('All required packages verified successfully')
except ImportError as e:
    print(f'Import error: {e}')
    quit(1)
"

# Create Python package structure
touch backend/__init__.py
touch backend/codec/__init__.py

# Create codec utilities
cat > backend/codec/utils.py << 'EOF'
import cv2
import numpy as np
from dataclasses import dataclass
from typing import Dict
from pathlib import Path
import time

def process_binary(input_path: str, output_path: str) -> Dict:
    start_time = time.time()
    
    cap = cv2.VideoCapture(input_path)
    if not cap.isOpened():
        raise ValueError("Could not open input video")
        
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps = int(cap.get(cv2.CAP_PROP_FPS))
    
    # Use H264 with specific parameters for macOS
    fourcc = cv2.VideoWriter_fourcc('a', 'v', 'c', '1')
    output_path = str(output_path).replace('.webm', '.mp4')  # Use mp4 container
    out = cv2.VideoWriter(str(output_path), fourcc, fps, (width, height))
    
    total_psnr = 0
    frame_count = 0
    
    while True:
        ret, frame = cap.read()
        if not ret:
            break
            
        # Apply compression
        encoded = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 60])[1]
        decoded = cv2.imdecode(encoded, cv2.IMREAD_COLOR)
        out.write(decoded)
        
        mse = np.mean((frame - decoded) ** 2)
        psnr = float('inf') if mse == 0 else 20 * np.log10(255.0 / np.sqrt(mse))
        total_psnr += psnr
        frame_count += 1
    
    cap.release()
    out.release()
    
    input_size = Path(input_path).stat().st_size
    output_size = Path(output_path).stat().st_size
    
    return {
        'psnr': total_psnr / frame_count if frame_count > 0 else 0,
        'compression_ratio': output_size / input_size,
        'processing_time': (time.time() - start_time) * 1000
    }

def process_ternary(input_path: str, output_path: str) -> Dict:
    from .ternary_codec import encode_video
    output_path = str(output_path).replace('.tern', '.mp4')
    metrics = encode_video(input_path, output_path)
    
    if 'output_path' in metrics:
        metrics['output_path'] = output_path
    return metrics
EOF

# Create ternary codec implementation
cat > backend/codec/ternary_codec.py << 'EOF'
import numpy as np
import cv2
from dataclasses import dataclass
from typing import List, Tuple
import struct
import io
import time
from pathlib import Path

@dataclass
class TernaryFrame:
    width: int
    height: int
    y_plane: np.ndarray
    cb_plane: np.ndarray
    cr_plane: np.ndarray
    motion_vectors: np.ndarray

class TernaryCodec:
    def __init__(self, width: int, height: int, framerate: int = 30):
        self.width = width
        self.height = height
        self.framerate = framerate
        self.block_size = 8
        self.previous_frame = None
        self.metrics = {
            'psnr': [],
            'compression_ratio': [],
            'processing_time': []
        }

        # Optimized quantization matrix
        self.y_quant = np.array([
            [8, 6, 5, 8, 12, 20, 26, 31],
            [6, 6, 7, 10, 13, 29, 30, 28],
            [7, 7, 8, 12, 20, 29, 35, 28],
            [7, 9, 11, 15, 26, 44, 40, 31],
            [9, 11, 19, 28, 34, 55, 52, 39],
            [12, 18, 28, 32, 41, 52, 57, 46],
            [25, 32, 39, 44, 52, 61, 60, 51],
            [36, 46, 48, 49, 56, 50, 52, 50]
        ], dtype=np.float32)

        # Quality parameters
        self.quality = 3.5  # Reduced from 5.0 for better quality
        self.y_quant = self.y_quant * self.quality
        self.c_quant = self.y_quant * 1.2  # Reduced from 1.5 for better color

        # Frequency importance matrix (exponential decay)
        self.importance = np.zeros((8, 8), dtype=np.float32)
        for i in range(8):
            for j in range(8):
                self.importance[i, j] = np.exp(-(i + j) / 4.0)

    def _to_ternary(self, value: float, threshold: float, importance: float) -> int:
        """Improved ternary conversion with importance weighting"""
        abs_val = abs(value)
        adj_threshold = threshold * (1.0 - importance * 0.5)  # Lower threshold for important coeffs
        if abs_val < adj_threshold:
            return 0
        return 1 if value > 0 else -1

    def _process_dct_block(self, dct_block: np.ndarray, quant_matrix: np.ndarray) -> np.ndarray:
        """Enhanced DCT block processing"""
        # Initial quantization
        quantized = dct_block / quant_matrix
        
        # Special handling for DC coefficient
        dc_value = quantized[0, 0]
        result = np.zeros_like(quantized)
        result[0, 0] = dc_value
        
        # Process AC coefficients with importance-based thresholding
        for i in range(8):
            for j in range(8):
                if i == 0 and j == 0:
                    continue
                
                importance = self.importance[i, j]
                threshold = 0.08 * (1.0 + i + j) / self.importance[i, j]
                result[i, j] = self._to_ternary(quantized[i, j], threshold, importance)
        
        # Adaptive smoothing for high frequencies
        high_freq_mask = (abs(result) > 0) & (self.importance < 0.3)
        result[high_freq_mask] *= 0.8  # Reduce high frequency artifacts
        
        return result * quant_matrix

    def _process_channel(self, channel: np.ndarray, is_luma: bool) -> np.ndarray:
        height, width = channel.shape
        processed = np.zeros_like(channel, dtype=np.float32)
        quant_matrix = self.y_quant if is_luma else self.c_quant

        # Add small border to reduce block artifacts
        border = 4
        padded = cv2.copyMakeBorder(channel, border, border, border, border, cv2.BORDER_REFLECT)

        for y in range(0, height - self.block_size + 1, self.block_size):
            for x in range(0, width - self.block_size + 1, self.block_size):
                # Extract larger block for overlap
                y_pad = y + border
                x_pad = x + border
                block = padded[y_pad:y_pad+self.block_size+2, x_pad:x_pad+self.block_size+2].astype(np.float32)
                
                # Process core 8x8 block
                core_block = block[1:-1, 1:-1] - 128.0
                dct_block = cv2.dct(core_block)
                processed_dct = self._process_dct_block(dct_block, quant_matrix)
                idct_block = cv2.idct(processed_dct) + 128.0
                
                # Store with slight overlap blending
                processed[y:y+self.block_size, x:x+self.block_size] = np.clip(idct_block, 0, 255)

        # Apply light deblocking filter
        if is_luma:
            processed = cv2.fastNlMeansDenoising(processed.astype(np.uint8), None, 3, 7, 21)

        return processed.astype(np.uint8)

    def encode_frame(self, frame: np.ndarray) -> TernaryFrame:
        # Convert to YCrCb
        ycrcb = cv2.cvtColor(frame, cv2.COLOR_BGR2YCrCb)
        y, cr, cb = cv2.split(ycrcb)

        # Process channels
        y_processed = self._process_channel(y, is_luma=True)
        
        # Chroma subsampling and processing
        cb_sub = cv2.resize(cb, (self.width // 2, self.height // 2), interpolation=cv2.INTER_LANCZOS4)
        cr_sub = cv2.resize(cr, (self.width // 2, self.height // 2), interpolation=cv2.INTER_LANCZOS4)
        
        cb_processed = self._process_channel(cb_sub, is_luma=False)
        cr_processed = self._process_channel(cr_sub, is_luma=False)

        # Calculate PSNR and update metrics
        if self.previous_frame is not None:
            psnr = self._calculate_psnr(y, y_processed)
            self.metrics['psnr'].append(psnr)

        self.previous_frame = y.copy()
        
        motion_vectors = np.zeros((self.height // self.block_size, 
                                 self.width // self.block_size, 2), dtype=np.int8)

        return TernaryFrame(
            width=self.width,
            height=self.height,
            y_plane=y_processed,
            cb_plane=cb_processed,
            cr_plane=cr_processed,
            motion_vectors=motion_vectors
        )

    def _calculate_psnr(self, original: np.ndarray, compressed: np.ndarray) -> float:
        mse = np.mean((original.astype(float) - compressed.astype(float)) ** 2)
        return float(20 * np.log10(255.0 / np.sqrt(max(mse, 1e-10))))

def encode_video(input_path: str, output_path: str) -> dict:
    cap = cv2.VideoCapture(input_path)
    if not cap.isOpened():
        raise ValueError("Could not open input video")
    
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps = int(cap.get(cv2.CAP_PROP_FPS))
    
    codec = TernaryCodec(width, height, fps)
    fourcc = cv2.VideoWriter_fourcc('a', 'v', 'c', '1')
    out = cv2.VideoWriter(output_path, fourcc, fps, (width, height))
    
    start_time = time.time()
    frame_count = 0
    
    while True:
        ret, frame = cap.read()
        if not ret:
            break
        
        ternary_frame = codec.encode_frame(frame)
        
        # Reconstruct with high-quality interpolation
        ycrcb = cv2.merge([
            ternary_frame.y_plane,
            cv2.resize(ternary_frame.cr_plane, (width, height), interpolation=cv2.INTER_LANCZOS4),
            cv2.resize(ternary_frame.cb_plane, (width, height), interpolation=cv2.INTER_LANCZOS4)
        ])
        
        bgr = cv2.cvtColor(ycrcb, cv2.COLOR_YCrCb2BGR)
        out.write(bgr)
        frame_count += 1
    
    cap.release()
    out.release()
    
    # Calculate metrics
    processing_time = float(time.time() - start_time)
    avg_psnr = float(np.mean(codec.metrics['psnr']) if codec.metrics['psnr'] else 0.0)
    
    input_size = float(Path(input_path).stat().st_size)
    output_size = float(Path(output_path).stat().st_size)
    compression_ratio = float(output_size / input_size)
    
    return {
        'psnr': avg_psnr,
        'compression_ratio': compression_ratio,
        'processing_time': processing_time * 1000
    }
EOF

# Create FastAPI application
cat > backend/main.py << 'EOF'
from fastapi import FastAPI, UploadFile, File, HTTPException, BackgroundTasks, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, FileResponse, StreamingResponse
from pathlib import Path
import json
from typing import Dict
import time
import asyncio
import cv2
import numpy as np
import os
from codec.utils import process_binary, process_ternary

app = FastAPI()

origins = [
    "http://localhost:3000",
    "http://127.0.0.1:3000",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"]
)

jobs = {}

@app.get("/health")
async def health_check():
    return {"status": "healthy"}

@app.post("/api/upload")
async def upload_video(file: UploadFile = File(...), background_tasks: BackgroundTasks = None):
    try:
        job_id = f"job_{int(time.time() * 1000)}"
        
        file_path = Path("../data/uploads") / file.filename
        file_path.parent.mkdir(parents=True, exist_ok=True)
        
        content = await file.read()
        with open(file_path, "wb") as buffer:
            buffer.write(content)
        
        jobs[job_id] = {
            "status": "uploading",
            "progress": 100,
            "filename": file.filename
        }
        
        background_tasks.add_task(process_video, job_id, file_path)
        
        return JSONResponse({
            "job_id": job_id,
            "status": "processing"
        })
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/status/{job_id}")
async def get_job_status(job_id: str):
    if job_id not in jobs:
        raise HTTPException(status_code=404, detail="Job not found")
    
    job = jobs[job_id]
    
    # Convert numpy types to Python native types
    if 'binary_metrics' in job:
        job['binary_metrics'] = {
            'psnr': float(job['binary_metrics']['psnr']),
            'compression_ratio': float(job['binary_metrics']['compression_ratio']),
            'processing_time': float(job['binary_metrics']['processing_time'])
        }
    
    if 'ternary_metrics' in job:
        job['ternary_metrics'] = {
            'psnr': float(job['ternary_metrics']['psnr']),
            'compression_ratio': float(job['ternary_metrics']['compression_ratio']),
            'processing_time': float(job['ternary_metrics']['processing_time'])
        }
    
    return job

@app.get("/api/video/{job_id}/{format}")
async def get_video(job_id: str, format: str, range: str = Header(None)):
    if job_id not in jobs:
        raise HTTPException(status_code=404, detail="Job not found")
    
    job = jobs[job_id]
    if "output_paths" not in job:
        raise HTTPException(status_code=404, detail="Video not ready")
        
    file_path = Path(job["output_paths"][format])
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="Video file not found")

    file_size = os.path.getsize(file_path)
    
    if format == "binary":
        media_type = "video/mp4"
        content_disposition = f'inline; filename="{job_id}_video.mp4"'
    else:
        media_type = "video/mp4"
        content_disposition = f'inline; filename="{job_id}_video.mp4"'

    # Handle range requests
    if range is not None:
        start_str, end_str = range.replace("bytes=", "").split("-")
        start = int(start_str)
        end = int(end_str) if end_str else file_size - 1
        chunk_size = end - start + 1

        headers = {
            'Content-Range': f'bytes {start}-{end}/{file_size}',
            'Accept-Ranges': 'bytes',
            'Content-Length': str(chunk_size),
            'Content-Type': media_type,
            'Content-Disposition': content_disposition,
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Expose-Headers': 'Content-Range',
        }

        async def stream_file():
            with open(file_path, "rb") as video:
                video.seek(start)
                chunk = video.read(chunk_size)
                yield chunk

        return StreamingResponse(
            stream_file(),
            status_code=206,
            headers=headers
        )
    else:
        # Full file response
        headers = {
            'Accept-Ranges': 'bytes',
            'Content-Length': str(file_size),
            'Content-Type': media_type,
            'Content-Disposition': content_disposition,
            'Access-Control-Allow-Origin': '*',
        }

        async def stream_file():
            with open(file_path, "rb") as video:
                while chunk := video.read(8192):
                    yield chunk

        return StreamingResponse(
            stream_file(),
            headers=headers
        )

async def process_video(job_id: str, file_path: Path):
    try:
        jobs[job_id].update({
            "status": "processing_binary",
            "progress": 0
        })
        
        binary_output = Path("../data/outputs") / f"{job_id}_binary.mp4"
        binary_metrics = process_binary(file_path, binary_output)
        
        # Convert binary metrics
        binary_metrics = {
            'psnr': float(binary_metrics['psnr']),
            'compression_ratio': float(binary_metrics['compression_ratio']),
            'processing_time': float(binary_metrics['processing_time'])
        }
        
        jobs[job_id].update({
            "status": "processing_ternary",
            "progress": 50
        })
        
        ternary_output = Path("../data/outputs") / f"{job_id}.mp4"
        ternary_metrics = process_ternary(file_path, ternary_output)
        
        # Convert ternary metrics
        ternary_metrics = {
            'psnr': float(ternary_metrics['psnr']),
            'compression_ratio': float(ternary_metrics['compression_ratio']),
            'processing_time': float(ternary_metrics['processing_time'])
        }
        
        jobs[job_id].update({
            "status": "completed",
            "progress": 100,
            "binary_metrics": binary_metrics,
            "ternary_metrics": ternary_metrics,
            "output_paths": {
                "binary": str(binary_output),
                "ternary": str(ternary_output)
            }
        })
        
    except Exception as e:
        jobs[job_id].update({
            "status": "failed",
            "error": str(e)
        })

EOF

echo "Backend core setup complete..."
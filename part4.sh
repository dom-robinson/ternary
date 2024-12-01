# part4.sh
#!/bin/bash

# Create video comparison components
echo "Creating video comparison components..."

# Create VideoUploader component
cat > frontend/src/components/VideoUploader.tsx << 'EOF'
'use client';

import { useState, useEffect } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Progress } from '@/components/ui/progress';
import { uploadVideo, getJobStatus, ProcessingStatus } from '@/lib/api';
import { VideoComparisonView } from './VideoComparisonView';
import { MetricsDisplay } from './MetricsDisplay';
import { ProcessingIndicator } from './ProcessingIndicator';
import { Loader2, Upload } from 'lucide-react';

export function VideoUploader() {
  const [file, setFile] = useState<File | null>(null);
  const [uploadProgress, setUploadProgress] = useState<number>(0);
  const [jobId, setJobId] = useState<string | null>(null);
  const [processingStatus, setProcessingStatus] = useState<ProcessingStatus | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [uploading, setUploading] = useState(false);

  useEffect(() => {
    if (!jobId) return;

    const pollStatus = async () => {
      try {
        const status = await getJobStatus(jobId);
        setProcessingStatus(status);
        
        if (status.status === 'completed' || status.status === 'failed') {
          return;
        }

        // Continue polling while processing
        setTimeout(pollStatus, 1000);
      } catch (err) {
        console.error('Error polling status:', err);
        setError('Failed to get processing status. Please try refreshing the page.');
      }
    };

    pollStatus();
  }, [jobId]);

  const handleUpload = async () => {
    if (!file) return;
    
    try {
      setError(null);
      setUploadProgress(0);
      setUploading(true);
      
      console.log('Starting upload of file:', file.name, 'size:', file.size);
      
      const result = await uploadVideo(file, (progress) => {
        console.log('Upload progress:', progress);
        setUploadProgress(progress);
      });
      
      console.log('Upload complete, received job ID:', result.job_id);
      setJobId(result.job_id);
    } catch (err) {
      console.error('Upload error:', err);
      setError(err instanceof Error ? err.message : 'Upload failed');
    } finally {
      setUploading(false);
    }
  };

  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const selectedFile = e.target.files?.[0];
    if (selectedFile) {
      setFile(selectedFile);
      setJobId(null);
      setProcessingStatus(null);
      setError(null);
      setUploadProgress(0);
      console.log('File selected:', selectedFile.name, 'size:', selectedFile.size);
    }
  };

  const isProcessing = jobId && processingStatus?.status !== 'completed' && processingStatus?.status !== 'failed';

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle>Upload Video</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <input
              type="file"
              accept="video/*"
              onChange={handleFileSelect}
              className="w-full p-2 border rounded"
              disabled={uploading || isProcessing}
            />

            {file && !isProcessing && !jobId && (
            <Button
                onClick={handleUpload}
                disabled={uploading || isProcessing}
                className="w-full bg-blue-500 hover:bg-blue-600 text-white flex items-center justify-center"
              >
                {uploading ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    Uploading...
                  </>
                ) : isProcessing ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    {processingStatus?.status === 'processing_binary' ? 'Processing Binary...' : 
                     processingStatus?.status === 'processing_ternary' ? 'Processing Ternary...' : 
                     'Processing...'}
                  </>
                ) : (
                  <>
                    <Upload className="mr-2 h-4 w-4" />
                    Start Processing
                  </>
                )}
              </Button>
            )}

            {(uploading || uploadProgress > 0) && (
              <div className="space-y-2">
                <div className="flex justify-between text-sm text-gray-600">
                  <span>Uploading {file?.name}...</span>
                  <span>{uploadProgress.toFixed(1)}%</span>
                </div>
                <Progress value={uploadProgress} />
              </div>
            )}

            {isProcessing && processingStatus && (
              <ProcessingIndicator status={processingStatus} />
            )}

            {error && (
              <div className="p-4 bg-red-50 border border-red-200 rounded text-red-600 text-sm">
                {error}
                <pre className="mt-2 text-xs overflow-auto">
                  {error}
                </pre>
              </div>
            )}
          </div>
        </CardContent>
      </Card>

      {processingStatus?.status === 'completed' && jobId && (
        <>
          <VideoComparisonView jobId={jobId} status={processingStatus} />
          <MetricsDisplay status={processingStatus} />
        </>
      )}
    </div>
  );
}
EOF

# Create VideoComparisonView component
cat > frontend/src/components/VideoComparisonView.tsx << 'EOF'
import { useEffect, useRef, useState } from 'react';
import { getVideoUrl } from '@/lib/api';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Slider } from '@/components/ui/slider';
import { Button } from '@/components/ui/button';
import { Play, Pause, SkipBack, SkipForward } from 'lucide-react';
import { ProcessingStatus } from '@/lib/api';

export function VideoComparisonView({ jobId, status }: { 
  jobId: string;
  status: ProcessingStatus; 
}) {
  const [playing, setPlaying] = useState(false);
  const [progress, setProgress] = useState(0);
  const [splitPosition, setSplitPosition] = useState(50);
  const [error, setError] = useState<string | null>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const binaryVideoRef = useRef<HTMLVideoElement>(null);
  const ternaryVideoRef = useRef<HTMLVideoElement>(null);

  const handleError = (e: Error, player: 'binary' | 'ternary') => {
    console.error(`Error in ${player} player:`, e);
    setError(`Failed to load ${player} video: ${e.message}`);
  };

  const handleProgress = (e: any) => {
    const video = e.target;
    setProgress((video.currentTime / video.duration) * 100);
    syncVideos();
  };

  const syncVideos = () => {
    if (binaryVideoRef.current && ternaryVideoRef.current) {
      const binaryTime = binaryVideoRef.current.currentTime;
      const ternaryTime = ternaryVideoRef.current.currentTime;
      
      if (Math.abs(binaryTime - ternaryTime) > 0.5) {
        if (binaryTime > ternaryTime) {
          ternaryVideoRef.current.currentTime = binaryTime;
        } else {
          binaryVideoRef.current.currentTime = ternaryTime;
        }
      }
    }
  };

  const handleSeek = (amount: number) => {
    if (binaryVideoRef.current) {
      const currentTime = binaryVideoRef.current.currentTime;
      const duration = binaryVideoRef.current.duration;
      const newTime = Math.max(0, Math.min(duration, currentTime + amount));
      binaryVideoRef.current.currentTime = newTime;
      if (ternaryVideoRef.current) {
        ternaryVideoRef.current.currentTime = newTime;
      }
    }
  };

  const togglePlay = () => {
    setPlaying(!playing);
    if (binaryVideoRef.current && ternaryVideoRef.current) {
      if (playing) {
        binaryVideoRef.current.pause();
        ternaryVideoRef.current.pause();
      } else {
        binaryVideoRef.current.play();
        ternaryVideoRef.current.play();
      }
    }
  };

  if (!status.output_paths) return null;

  return (
    <Card>
      <CardHeader>
        <CardTitle>Video Comparison</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="space-y-4">
          {error && (
            <div className="p-4 bg-red-50 border border-red-200 rounded text-red-600 text-sm">
              {error}
            </div>
          )}
          
          {/* Main video container */}
          <div ref={containerRef} className="relative aspect-video min-h-[400px] bg-gray-100">
            {/* Base layer - Binary video */}
            <video
              ref={binaryVideoRef}
              src={getVideoUrl(jobId, 'binary')}
              onTimeUpdate={handleProgress}
              onError={(e) => handleError(e as any, 'binary')}
              controls={false}
              playsInline
              className="absolute inset-0 w-full h-full object-cover"
            >
              <source src={getVideoUrl(jobId, 'binary')} type="video/mp4" />
            </video>
            
            {/* Overlay layer - Ternary video with clip mask */}
            <div 
              className="absolute top-0 left-0 h-full overflow-hidden"
              style={{ width: `${splitPosition}%` }}
            >
              <video
                ref={ternaryVideoRef}
                src={getVideoUrl(jobId, 'ternary')}
                onError={(e) => handleError(e as any, 'ternary')}
                controls={false}
                playsInline
                className="absolute top-0 left-0 h-full object-cover"
                style={{ 
                  width: '100vw',  // Make sure it's at least as wide as the viewport
                  maxWidth: 'none' // Prevent max-width constraints
                }}
              >
                <source src={getVideoUrl(jobId, 'ternary')} type="video/mp4" />
              </video>
            </div>
            
            {/* Divider line */}
            <div
              className="absolute top-0 bottom-0 w-1 bg-white cursor-col-resize shadow-lg"
              style={{ left: `${splitPosition}%`, transform: 'translateX(-50%)' }}
            />
          </div>

          <div className="space-y-4">
            <Slider
              value={[splitPosition]}
              onValueChange={(values) => setSplitPosition(values[0])}
              max={100}
              step={1}
              className="h-4"
            />
            <div className="flex justify-between text-sm text-gray-500">
              <span>Ternary</span>
              <span>Binary</span>
            </div>
          </div>

          <div className="flex justify-center space-x-4">
            <Button
              variant="outline"
              size="icon"
              onClick={() => handleSeek(-5)}
            >
              <SkipBack className="h-4 w-4" />
            </Button>
            <Button
              variant="outline"
              size="icon"
              onClick={togglePlay}
            >
              {playing ? (
                <Pause className="h-4 w-4" />
              ) : (
                <Play className="h-4 w-4" />
              )}
            </Button>
            <Button
              variant="outline"
              size="icon"
              onClick={() => handleSeek(5)}
            >
              <SkipForward className="h-4 w-4" />
            </Button>
          </div>

          <div className="h-1 bg-gray-200 rounded">
            <div 
              className="h-full bg-blue-500 rounded transition-all"
              style={{ width: `${progress}%` }}
            />
          </div>
        </div>
      </CardContent>
    </Card>
  );
}
EOF

# Create MetricsDisplay component
cat > frontend/src/components/MetricsDisplay.tsx << 'EOF'
'use client';

import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { ProcessingStatus } from '@/lib/api';

export function MetricsDisplay({ status }: { status: ProcessingStatus }) {
  if (!status.binary_metrics || !status.ternary_metrics) return null;

  return (
    <Card>
      <CardHeader>
        <CardTitle>Compression Metrics</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="grid grid-cols-2 gap-4">
          <div>
            <h4 className="text-lg font-semibold mb-2">Binary Compression</h4>
            <dl className="space-y-1">
              <div className="flex justify-between">
                <dt>PSNR:</dt>
                <dd>{status.binary_metrics.psnr.toFixed(2)} dB</dd>
              </div>
              <div className="flex justify-between">
                <dt>Compression Ratio:</dt>
                <dd>{(status.binary_metrics.compression_ratio * 100).toFixed(1)}%</dd>
              </div>
              <div className="flex justify-between">
                <dt>Processing Time:</dt>
                <dd>{status.binary_metrics.processing_time.toFixed(2)}ms</dd>
              </div>
            </dl>
          </div>

          <div>
            <h4 className="text-lg font-semibold mb-2">Ternary Compression</h4>
            <dl className="space-y-1">
              <div className="flex justify-between">
                <dt>PSNR:</dt>
                <dd>{status.ternary_metrics.psnr.toFixed(2)} dB</dd>
              </div>
              <div className="flex justify-between">
                <dt>Compression Ratio:</dt>
                <dd>{(status.ternary_metrics.compression_ratio * 100).toFixed(1)}%</dd>
              </div>
              <div className="flex justify-between">
                <dt>Processing Time:</dt>
                <dd>{status.ternary_metrics.processing_time.toFixed(2)}ms</dd>
              </div>
            </dl>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}
EOF

# Create ProcessingIndicator component
cat > frontend/src/components/ProcessingIndicator.tsx << 'EOF'
import { Progress } from '@/components/ui/progress';
import { ProcessingStatus } from '@/lib/api';

export function ProcessingIndicator({ status }: { status: ProcessingStatus }) {
  const getStatusInfo = () => {
    switch (status.status) {
      case 'processing_binary':
        return {
          text: 'Binary Compression',
          subtext: 'Processing standard compression...',
          progress: 25 + (status.progress / 4)  // 25-50%
        };
      case 'processing_ternary':
        return {
          text: 'Ternary Compression',
          subtext: 'Processing enhanced compression...',
          progress: 50 + (status.progress / 2)  // 50-100%
        };
      case 'uploading':
        return {
          text: 'Upload',
          subtext: 'Uploading video file...',
          progress: (status.progress / 4)  // 0-25%
        };
      case 'completed':
        return {
          text: 'Complete',
          subtext: 'Processing finished successfully',
          progress: 100
        };
      case 'failed':
        return {
          text: 'Failed',
          subtext: 'Error during processing',
          progress: 0
        };
      default:
        return {
          text: 'Processing',
          subtext: 'Please wait...',
          progress: 0
        };
    }
  };

  const info = getStatusInfo();

  return (
    <div className="space-y-4 p-4 bg-gray-50 rounded-lg">
      <div className="space-y-2">
        <div className="flex justify-between items-center">
          <div>
            <h4 className="font-semibold text-sm">{info.text}</h4>
            <p className="text-sm text-gray-500">{info.subtext}</p>
          </div>
          <span className="text-sm font-medium">{Math.round(info.progress)}%</span>
        </div>
        <Progress 
          value={info.progress} 
          className="h-2" 
        />
      </div>
      
      {status.error && (
        <div className="p-3 bg-red-50 border border-red-200 rounded-md">
          <p className="text-sm text-red-600">{status.error}</p>
        </div>
      )}
    </div>
  );
}
EOF
EOF

echo "Video comparison components setup complete..."
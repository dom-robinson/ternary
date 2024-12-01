# part3.sh
#!/bin/bash

# Create API client and base components
echo "Creating API client and base components..."

# Create API client
cat > frontend/src/lib/api.ts << 'EOF'
const API_URL = 'http://127.0.0.1:8000';

export interface ProcessingStatus {
  status: 'uploading' | 'processing_binary' | 'processing_ternary' | 'completed' | 'failed';
  progress: number;
  filename?: string;
  binary_metrics?: {
    psnr: number;
    compression_ratio: number;
    processing_time: number;
  };
  ternary_metrics?: {
    psnr: number;
    compression_ratio: number;
    processing_time: number;
  };
  output_paths?: {
    binary: string;
    ternary: string;
  };
  error?: string;
}

export async function uploadVideo(
  file: File,
  onProgress: (progress: number) => void
): Promise<{ job_id: string }> {
  const formData = new FormData();
  formData.append('file', file);

  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();

    // Upload progress handler
    xhr.upload.addEventListener('progress', (event) => {
      if (event.lengthComputable) {
        const progress = (event.loaded / event.total) * 100;
        onProgress(progress);
        console.log(`Upload progress: ${progress.toFixed(1)}% (${event.loaded}/${event.total} bytes)`);
      }
    });

    // Upload complete handler
    xhr.upload.addEventListener('load', () => {
      console.log('Upload completed, waiting for server response...');
    });

    // Response handler
    xhr.addEventListener('load', () => {
      if (xhr.status >= 200 && xhr.status < 300) {
        try {
          const response = JSON.parse(xhr.responseText);
          console.log('Server response:', response);
          resolve(response);
        } catch (error) {
          console.error('Failed to parse server response:', xhr.responseText);
          reject(new Error('Invalid server response'));
        }
      } else {
        console.error('Upload failed with status:', xhr.status);
        reject(new Error(`Upload failed with status ${xhr.status}`));
      }
    });

    // Error handler
    xhr.addEventListener('error', () => {
      console.error('Upload failed due to network error');
      reject(new Error('Network error occurred during upload'));
    });

    // Abort handler
    xhr.addEventListener('abort', () => {
      console.error('Upload was aborted');
      reject(new Error('Upload was aborted'));
    });

    // Timeout handler
    xhr.addEventListener('timeout', () => {
      console.error('Upload timed out');
      reject(new Error('Upload timed out'));
    });

    // Send the request
    xhr.open('POST', `${API_URL}/api/upload`);
    xhr.send(formData);
  });
}

export async function getJobStatus(jobId: string): Promise<ProcessingStatus> {
  const response = await fetch(`${API_URL}/api/status/${jobId}`);
  if (!response.ok) {
    throw new Error(`Failed to fetch job status: ${response.statusText}`);
  }
  return response.json();
}

export function getVideoUrl(jobId: string, format: 'binary' | 'ternary'): string {
  return `${API_URL}/api/video/${jobId}/${format}`;
}
EOF

# Create utils
cat > frontend/src/lib/utils.ts << 'EOF'
import { type ClassValue, clsx } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

export function formatTime(ms: number): string {
  return `${(ms / 1000).toFixed(2)}s`;
}

export function formatPercentage(value: number): string {
  return `${(value * 100).toFixed(1)}%`;
}
EOF

# Create progress component
cat > frontend/src/components/ui/progress.tsx << 'EOF'
import * as React from "react"
import { cn } from "@/lib/utils"

export interface ProgressProps extends React.HTMLAttributes<HTMLDivElement> {
  value?: number;
}

const Progress = React.forwardRef<HTMLDivElement, ProgressProps>(
  ({ className, value, ...props }, ref) => (
    <div
      ref={ref}
      className={cn(
        "relative h-2 w-full overflow-hidden rounded-full bg-secondary",
        className
      )}
      {...props}
    >
      <div
        className="h-full w-full flex-1 bg-primary transition-all"
        style={{ transform: `translateX(-${100 - (value || 0)}%)` }}
      />
    </div>
  )
)
Progress.displayName = "Progress"

export { Progress }
EOF

# Create slider component with improved styling
cat > frontend/src/components/ui/slider.tsx << 'EOF'
import * as React from "react"
import { cn } from "@/lib/utils"

export interface SliderProps extends React.HTMLAttributes<HTMLDivElement> {
  value?: number[];
  onValueChange?: (value: number[]) => void;
  max?: number;
  step?: number;
}

const Slider = React.forwardRef<HTMLDivElement, SliderProps>(
  ({ className, value = [0], onValueChange, max = 100, step = 1, ...props }, ref) => {
    const handlePointerDown = (event: React.PointerEvent) => {
      const rect = event.currentTarget.getBoundingClientRect();
      const pos = (event.clientX - rect.left) / rect.width;
      onValueChange?.([Math.round(pos * max / step) * step]);
    };

    return (
      <div
        ref={ref}
        className={cn("relative h-4 w-full touch-none", className)}
        onPointerDown={handlePointerDown}
        {...props}
      >
        <div className="absolute h-full w-full rounded-full bg-secondary">
          <div
            className="absolute h-full rounded-full bg-primary"
            style={{ width: `${(value[0] / max) * 100}%` }}
          />
        </div>
        <div
          className="absolute h-8 w-8 rounded-full border-4 border-primary bg-background -translate-x-1/2 -translate-y-1/4 cursor-grab active:cursor-grabbing shadow-lg hover:scale-110 transition-transform"
          style={{ left: `${(value[0] / max) * 100}%` }}
        />
      </div>
    )
  }
)
Slider.displayName = "Slider"

export { Slider }
EOF

# Create card component
cat > frontend/src/components/ui/card.tsx << 'EOF'
import * as React from "react"
import { cn } from "@/lib/utils"

const Card = React.forwardRef<HTMLDivElement, React.HTMLAttributes<HTMLDivElement>>(
  ({ className, ...props }, ref) => (
    <div
      ref={ref}
      className={cn(
        "rounded-lg border bg-card text-card-foreground shadow-sm",
        className
      )}
      {...props}
    />
  )
)
Card.displayName = "Card"

const CardHeader = React.forwardRef<HTMLDivElement, React.HTMLAttributes<HTMLDivElement>>(
  ({ className, ...props }, ref) => (
    <div
      ref={ref}
      className={cn("flex flex-col space-y-1.5 p-6", className)}
      {...props}
    />
  )
)
CardHeader.displayName = "CardHeader"

const CardTitle = React.forwardRef<HTMLHeadingElement, React.HTMLAttributes<HTMLHeadingElement>>(
  ({ className, ...props }, ref) => (
    <h3
      ref={ref}
      className={cn("text-2xl font-semibold leading-none tracking-tight", className)}
      {...props}
    />
  )
)
CardTitle.displayName = "CardTitle"

const CardContent = React.forwardRef<HTMLDivElement, React.HTMLAttributes<HTMLDivElement>>(
  ({ className, ...props }, ref) => (
    <div ref={ref} className={cn("p-6 pt-0", className)} {...props} />
  )
)
CardContent.displayName = "CardContent"

export { Card, CardHeader, CardTitle, CardContent }
EOF

# Create button component
cat > frontend/src/components/ui/button.tsx << 'EOF'
import * as React from "react"
import { type VariantProps } from "class-variance-authority"
import { cn } from "@/lib/utils"

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'default' | 'outline' | 'ghost' | 'link';
  size?: 'default' | 'sm' | 'lg' | 'icon';
  asChild?: boolean;
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant = "default", size = "default", asChild = false, ...props }, ref) => {
    return (
      <button
        className={cn(
          "inline-flex items-center justify-center whitespace-nowrap rounded-md text-sm font-medium ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50",
          {
            "bg-primary text-primary-foreground hover:bg-primary/90": variant === "default",
            "border border-input bg-background hover:bg-accent hover:text-accent-foreground": variant === "outline",
            "hover:bg-accent hover:text-accent-foreground": variant === "ghost",
            "text-primary underline-offset-4 hover:underline": variant === "link",
            "h-10 px-4 py-2": size === "default",
            "h-9 rounded-md px-3": size === "sm",
            "h-11 rounded-md px-8": size === "lg",
            "h-10 w-10": size === "icon",
          },
          className
        )}
        ref={ref}
        {...props}
      />
    )
  }
)
Button.displayName = "Button"

export { Button }
EOF

echo "API client and base components setup complete..."
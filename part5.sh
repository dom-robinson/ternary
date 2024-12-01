# part5.sh
#!/bin/bash

# Create main pages and layouts
echo "Creating pages and layout..."

# Create main page
cat > frontend/src/app/page.tsx << 'EOF'
'use client';

import { VideoUploader } from '@/components/VideoUploader';

export default function Home() {
  return (
    <main className="min-h-screen bg-gray-50 pb-12">
      <div className="max-w-6xl mx-auto p-8">
        <header className="text-center mb-12">
          <h1 className="text-4xl font-bold mb-4">
            Video Compression Comparison
          </h1>
          <p className="text-xl text-gray-600 mb-2">
            Compare Binary vs Ternary Video Compression
          </p>
          <p className="text-gray-500">
            Upload a video to compare compression methods
          </p>
        </header>

        <div className="space-y-8">
          <section>
            <VideoUploader />
          </section>
        </div>
      </div>
    </main>
  );
}
EOF

# Create layout
cat > frontend/src/app/layout.tsx << 'EOF'
import './globals.css';
import { Inter } from 'next/font/google';

const inter = Inter({ subsets: ['latin'] });

export const metadata = {
  title: 'Video Compression Comparison',
  description: 'Compare binary and ternary video compression methods',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className="antialiased">
      <body className={inter.className}>
        {children}
        
        <footer className="bg-white border-t mt-auto">
          <div className="max-w-6xl mx-auto py-6 px-4">
            <div className="text-center text-gray-500 text-sm">
              <p>Experimental demonstration for research purposes</p>
            </div>
          </div>
        </footer>
      </body>
    </html>
  );
}
EOF

# Create loading state
cat > frontend/src/app/loading.tsx << 'EOF'
export default function Loading() {
  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <div className="text-center">
        <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-blue-500 mx-auto"></div>
        <p className="mt-4 text-gray-600">Loading...</p>
      </div>
    </div>
  );
}
EOF

# Create globals.css
cat > frontend/src/app/globals.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  :root {
    --background: 0 0% 100%;
    --foreground: 222.2 84% 4.9%;
    --card: 0 0% 100%;
    --card-foreground: 222.2 84% 4.9%;
    --popover: 0 0% 100%;
    --popover-foreground: 222.2 84% 4.9%;
    --primary: 222.2 47.4% 11.2%;
    --primary-foreground: 210 40% 98%;
    --secondary: 210 40% 96.1%;
    --secondary-foreground: 222.2 47.4% 11.2%;
    --muted: 210 40% 96.1%;
    --muted-foreground: 215.4 16.3% 46.9%;
    --accent: 210 40% 96.1%;
    --accent-foreground: 222.2 47.4% 11.2%;
    --destructive: 0 84.2% 60.2%;
    --destructive-foreground: 210 40% 98%;
    --border: 214.3 31.8% 91.4%;
    --input: 214.3 31.8% 91.4%;
    --ring: 222.2 84% 4.9%;
    --radius: 0.5rem;
  }
}

.video-compare-slider {
  position: relative;
  overflow: hidden;
  aspect-ratio: 16/9;
  min-height: 400px;
  background: #f3f4f6;
}

.video-compare-slider video {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.video-compare-slider .compare-overlay {
  position: absolute;
  top: 0;
  left: 0;
  height: 100%;
  overflow: hidden;
}

.video-compare-slider .video-controls {
  position: absolute;
  bottom: 20px;
  left: 50%;
  transform: translateX(-50%);
  z-index: 10;
}
EOF

# Create error page
cat > frontend/src/app/error.tsx << 'EOF'
'use client';

import { useEffect } from 'react';
import { Button } from '@/components/ui/button';

export default function Error({
  error,
  reset,
}: {
  error: Error;
  reset: () => void;
}) {
  useEffect(() => {
    console.error(error);
  }, [error]);

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <div className="text-center">
        <h2 className="text-2xl font-bold text-gray-800 mb-4">
          Something went wrong!
        </h2>
        <p className="text-gray-600 mb-4">
          {error.message || 'An unexpected error occurred'}
        </p>
        <Button onClick={reset} variant="outline">
          Try again
        </Button>
      </div>
    </div>
  );
}
EOF

# Create not found page
cat > frontend/src/app/not-found.tsx << 'EOF'
import Link from 'next/link';
import { Button } from '@/components/ui/button';

export default function NotFound() {
  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <div className="text-center">
        <h2 className="text-4xl font-bold text-gray-800 mb-4">404</h2>
        <p className="text-xl text-gray-600 mb-6">Page not found</p>
        <Link href="/">
          <Button variant="outline">Return to home</Button>
        </Link>
      </div>
    </div>
  );
}
EOF

echo "Pages and layout setup complete..."
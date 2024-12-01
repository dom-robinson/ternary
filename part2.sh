# part2.sh
#!/bin/bash

# Frontend setup
echo "Setting up enhanced frontend..."

cd frontend || exit 1

# Create directory structure
mkdir -p src/{app,components,lib,hooks,context}
mkdir -p src/components/ui
mkdir -p src/components/analysis
mkdir -p public/temp

# Create package.json
cat > package.json << 'EOF'
{
  "name": "ternary-compression-frontend",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint"
  },
  "dependencies": {
    "next": "14.0.3",
    "react": "18.2.0",
    "react-dom": "18.2.0",
    "classnames": "2.3.2",
    "@radix-ui/react-slider": "^1.1.2",
    "@radix-ui/react-tooltip": "^1.0.7",
    "@radix-ui/react-progress": "^1.0.3",
    "class-variance-authority": "^0.7.0",
    "clsx": "^2.0.0",
    "recharts": "^2.10.1",
    "zustand": "^4.4.6",
    "lucide-react": "^0.301.0",
    "tailwind-merge": "^2.0.0",
    "@radix-ui/react-slot": "^1.0.2"
  },
  "devDependencies": {
    "@types/node": "20.9.0",
    "@types/react": "18.2.37",
    "@types/react-dom": "18.2.15",
    "autoprefixer": "10.4.16",
    "postcss": "8.4.31",
    "tailwindcss": "3.3.5",
    "typescript": "5.2.2",
    "tailwindcss-animate": "^1.0.7"
  }
}
EOF

# Create next.config.js
cat > next.config.js << 'EOF'
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  images: {
    domains: ['localhost', '127.0.0.1'],
  },
  webpack(config) {
    config.module.rules.push({
      test: /\.(mp4|webm|ogg)$/,
      use: {
        loader: 'file-loader',
        options: {
          publicPath: '/_next/static/videos/',
          outputPath: 'static/videos/',
          name: '[name].[hash].[ext]',
        },
      },
    });
    return config;
  },
}

module.exports = nextConfig
EOF

# Create tsconfig.json
cat > tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "target": "es5",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [
      {
        "name": "next"
      }
    ],
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
EOF

# Create postcss.config.js
cat > postcss.config.js << 'EOF'
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
EOF

# Create tailwind.config.js
cat > tailwind.config.js << 'EOF'
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './src/pages/**/*.{js,ts,jsx,tsx,mdx}',
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {},
  },
  plugins: [require("tailwindcss-animate")],
}
EOF

# Create empty directories with .gitkeep
touch public/temp/.gitkeep

# Install dependencies
echo "Installing frontend dependencies..."
npm install --legacy-peer-deps

cd ..

echo "Frontend framework setup complete..."
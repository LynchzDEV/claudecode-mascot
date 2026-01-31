# Docker Deployment Guide

## Quick Start

### 1. Pull and Run
```bash
# Generate secret key
SECRET_KEY_BASE=$(docker run --rm lynchz/claude-mascot bundle exec rails secret)

# Run with docker-compose
echo "SECRET_KEY_BASE=$SECRET_KEY_BASE" > .env
docker-compose up -d

# Or run directly
docker run -d \
  -p 3000:3000 \
  -e SECRET_KEY_BASE=$SECRET_KEY_BASE \
  --name claude-mascot \
  lynchz/claude-mascot:latest
```

Visit: http://localhost:3000

### 2. Stop
```bash
docker-compose down
# or
docker stop claude-mascot
```

---

## Build Multi-Architecture Images

### Prerequisites
```bash
# Install Docker Desktop or Docker with buildx
docker buildx version

# Login to Docker Hub
docker login
```

### Build & Push
```bash
# Use the provided script
./build-and-push.sh

# Or manually
docker buildx create --name claude-builder --use
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag lynchz/claude-mascot:latest \
  --push \
  .
```

---

## Production Deployment

### Using Docker Compose
```bash
# 1. Clone repo (or just download docker-compose.yml)
git clone <your-repo>
cd claude-mascot

# 2. Create .env file
cp .env.example .env
# Edit .env and set SECRET_KEY_BASE

# 3. Start
docker-compose up -d

# 4. Check logs
docker-compose logs -f

# 5. Check health
docker-compose ps
```

### Using Docker Run
```bash
docker run -d \
  --name claude-mascot \
  --restart unless-stopped \
  -p 3000:3000 \
  -e RAILS_ENV=production \
  -e SECRET_KEY_BASE=<your-secret> \
  -v $(pwd)/storage:/app/storage \
  -v $(pwd)/log:/app/log \
  lynchz/claude-mascot:latest
```

### Behind Nginx/Caddy
```nginx
# Nginx config
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

---

## Supported Architectures

- `linux/amd64` (x86_64)
- `linux/arm64` (Apple Silicon, ARM servers)

---

## Volumes

- `/app/storage` - Session database and uploaded files
- `/app/log` - Application logs

---

## Environment Variables

- `RAILS_ENV` - Set to `production`
- `SECRET_KEY_BASE` - **Required** for production
- `RAILS_LOG_TO_STDOUT` - Set to `true` for Docker logs
- `RAILS_SERVE_STATIC_FILES` - Set to `true` to serve assets

---

## Health Check

The container includes a health check on `http://localhost:3000/`

Check status:
```bash
docker ps
# Look for "healthy" status
```

---

## Updating

```bash
# Pull latest
docker-compose pull

# Restart
docker-compose up -d
```

---

## Troubleshooting

### View logs
```bash
docker-compose logs -f web
```

### Enter container
```bash
docker-compose exec web bash
```

### Reset database
```bash
docker-compose exec web bin/rails db:reset RAILS_ENV=production
```

### Generate new secret
```bash
docker run --rm lynchz/claude-mascot bundle exec rails secret
```

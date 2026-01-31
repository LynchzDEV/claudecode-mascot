# Multi-stage Dockerfile for Claude Mascot Rails App
FROM ruby:3.2.2-slim AS builder

# Install build dependencies
RUN apt-get update -qq && \
    apt-get install -y \
    build-essential \
    libsqlite3-dev \
    nodejs \
    npm \
    git \
    curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install gems
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    bundle install

# Copy app
COPY . .

# Precompile assets
RUN RAILS_ENV=production SECRET_KEY_BASE=dummy bundle exec rails assets:precompile && \
    RAILS_ENV=production SECRET_KEY_BASE=dummy bundle exec rails tailwindcss:build

# Production stage
FROM ruby:3.2.2-slim

# Install runtime dependencies
RUN apt-get update -qq && \
    apt-get install -y \
    libsqlite3-0 \
    curl && \
    rm -rf /var/lib/apt/lists/* && \
    useradd -m -u 1000 rails

WORKDIR /app

# Copy from builder
COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --from=builder --chown=rails:rails /app /app

# Create necessary directories
RUN mkdir -p /app/storage /app/tmp /app/log && \
    chown -R rails:rails /app

USER rails

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:3000/ || exit 1

# Start server
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]

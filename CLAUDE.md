# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A real-time Rails 8.1 web application that displays a visual mascot companion for Claude Code CLI. The mascot's eyes change states (idle, thinking, working, sleeping, happy, error) based on Claude Code hook events received via WebSocket connections.

**Key Architecture:** Multi-user SaaS deployment where each user gets a unique session token. The frontend connects to session-specific ActionCable channels, and hooks send authenticated requests to update the mascot state.

## Development Commands

### Starting the Server
```bash
bin/dev
```
Runs both the Rails server (port 3000) and Tailwind CSS watcher via Foreman.

### Database
```bash
rails db:migrate          # Run pending migrations
rails db:reset            # Drop, recreate, and migrate database
rails db:seed             # Seed database (if applicable)
```

### Testing
```bash
rails test                # Run all tests
rails test:system         # Run system tests only
rails test test/models/mascot_session_test.rb  # Run specific test file
```

### Code Quality
```bash
bundle exec rubocop       # Check Ruby style
bundle exec brakeman      # Security analysis
bundle exec bundler-audit # Check for vulnerable gems
```

### Asset Management
```bash
bin/rails tailwindcss:watch  # Watch and compile Tailwind CSS
bin/rails assets:precompile  # Precompile assets for production
```

## Architecture

### Multi-User Session System

The application supports multiple concurrent users, each with their own mascot session:

1. **Session Creation**: Users visit the homepage, which auto-creates a `MascotSession` with a unique UUID token
2. **Token-Based Authentication**: All API requests and WebSocket connections use `Authorization: Bearer <token>` headers
3. **Session-Specific Channels**: Each session subscribes to `mascot_state_#{token}` via ActionCable
4. **State Isolation**: Each session maintains independent state (idle, thinking, working, sleeping, happy, error)

**Key Models:**
- `MascotSession` (app/models/mascot_session.rb): Manages session state, token, name, and last_seen_at timestamp
  - `update_state!(new_state, event:, tool:)` - Updates state and broadcasts to session's WebSocket channel
  - `broadcast_state(event:, tool:)` - Broadcasts current state to `mascot_state_#{token}` channel
  - `channel_name` - Returns session-specific channel identifier

### WebSocket Architecture (ActionCable)

**Flow:**
1. Frontend JavaScript creates session via `POST /api/sessions`
2. Receives session token in response
3. Subscribes to `MascotChannel` with token parameter
4. `MascotChannel` (app/channels/mascot_channel.rb) validates token and subscribes to `mascot_state_#{token}`
5. When hooks fire, controller broadcasts state updates to session's channel
6. Frontend receives updates and animates eyes accordingly

**Key Files:**
- `app/channels/mascot_channel.rb` - Session-specific WebSocket channel subscription
- `app/javascript/channels/mascot_channel.js` - Frontend WebSocket consumer
- `config/cable.yml` - ActionCable configuration (uses Solid Cable for production)

### Hook Integration System

Claude Code hooks send HTTP POST requests to `/api/hooks/event` with:
- `event`: Event type (SessionStart, PreToolUse, PostToolUse, Stop, SessionEnd, Error)
- `tool`: Tool name (for PreToolUse/PostToolUse events)
- `timestamp`: ISO8601 timestamp
- `pid`: Claude CLI process ID (`$PPID` in bash)

**Event → State Mapping** (app/controllers/api/hooks_controller.rb:10-25):
- `SessionStart` → idle (mascot wakes up)
- `PreToolUse` → thinking (about to use a tool)
- `PostToolUse` → working (tool execution in progress)
- `Stop` → idle (tool finished)
- `Error` → error (X_X eyes)
- `SessionEnd` → sleeping (session ends)

**Hook Installation:**

Users can install hooks with a single curl command:
```bash
curl -sSL https://claude.lynchz.dev/install/YOUR_TOKEN | bash
```

This installer:
- Creates `~/.claude/hooks/` directory
- Downloads and installs all hook scripts (SessionStart, PreToolUse, PostToolUse, Stop, SessionEnd)
- Makes hooks executable automatically
- Embeds the session token directly in each hook script

**Hook Scripts** (.claude/hooks/):
All hooks are bash scripts that use `curl` to POST events asynchronously (background job with `> /dev/null 2>&1 &`).
Each hook is pre-configured with the session token and mascot URL during installation.

### Frontend State Management

**Main View:** `app/views/home/index.html.erb`
- Contains eye SVG elements with CSS-based animations
- Settings panel for session configuration
- JavaScript manages WebSocket connection and state transitions

**State Transitions:**
JavaScript function `window.updateMascotState(state, event)` applies CSS classes to eyes based on received state.

### API Endpoints

```
POST /api/sessions                    # Create new session
GET  /api/sessions/:token             # Get session info
PATCH /api/sessions/:token            # Update session name
POST /api/sessions/:token/regenerate  # Regenerate compromised token
GET  /api/sessions/:token/hooks       # Download ZIP of configured hook scripts

GET  /install/:token                  # Get one-line curl installer script (recommended)

POST /api/hooks/event                 # Receive hook event (requires Bearer token)
GET  /api/hooks/status                # Check session status (optional token)
```

### PID Monitoring (Currently Disabled)

Previously, the system monitored Claude CLI process IDs to auto-sleep when all processes exited. This is handled via `config/initializers/process_monitor.rb`, which defines a `ProcessMonitor` module with `process_alive?(pid)` checking.

**Note:** PID monitoring is currently disabled in favor of database-backed session management. Each session manages its own state.

### Session Management

Sessions are database-backed with:
- **Token:** UUID for authentication and channel subscription
- **Name:** User-friendly identifier (e.g., "My Laptop")
- **State:** Current mascot state (idle, thinking, working, sleeping, happy, error)
- **Last Seen At:** Timestamp of last activity (touched on API calls)

The settings panel allows users to:
- View/copy their session token
- Name their session
- Download pre-configured hook scripts (as ZIP)
- See connection status

## Important Conventions

### State Broadcasting
Always use `MascotSession#update_state!` to change state, not direct `update!`. This ensures WebSocket broadcasts occur.

### Hook Script Generation
When adding new hook types, update `Api::SessionsController#generate_hook_script` to include the event in ZIP downloads.

### Authentication
All `/api/hooks/event` requests require `Authorization: Bearer <token>` header. The token is validated via `MascotSession.find_by(token: token)`.

### WebSocket Channels
Use session-specific channel names (`mascot_state_#{token}`) to ensure state isolation between users.

### Background Jobs
Hook scripts run curl in background (`&` suffix) to avoid blocking Claude Code CLI operations.

## Technology Stack

- **Rails 8.1.2** - Backend framework
- **SQLite3** - Database (with Solid Cache, Solid Queue, Solid Cable)
- **ActionCable** - WebSocket implementation
- **Tailwind CSS** - Styling (via tailwindcss-rails)
- **Stimulus.js** - JavaScript framework
- **Turbo** - SPA-like navigation
- **Puma** - Web server
- **Foreman** - Process management (bin/dev)

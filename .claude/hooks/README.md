# Claude Code Hooks for Mascot Integration

These hooks connect your Claude Code CLI to the mascot web app to show real-time emotions.

## Setup

1. **Start the Rails server:**
   ```bash
   bin/dev
   ```

2. **Set environment variables (optional):**
   ```bash
   export MASCOT_URL="http://localhost:3000"
   export MASCOT_TOKEN="dev_token_change_me"
   ```

3. **The hooks are already executable and ready to use!**

## How It Works

- **SessionStart** - Fires when you run `claude` in terminal → Mascot wakes up from "sleeping" to "idle"
- **PreToolUse** - Fires when Claude is about to use a tool → Mascot shows "thinking" state
- **PostToolUse** - Fires after Claude uses a tool → Mascot shows "working" state
- **Stop** - Fires when Claude stops using a tool → Mascot returns to "idle" state

### Automatic Sleep Detection

The hooks now send the claude CLI process ID (PID) with each event. The Rails backend monitors these PIDs and **automatically puts the mascot to sleep when the claude process exits**. No manual configuration needed!

## Manual Sleep (Optional)

The mascot now sleeps automatically when you close ClaudeCode thanks to PID monitoring. However, you can also manually trigger sleep:

```bash
./.claude/hooks/SessionEnd
```

## Testing

Test the hooks manually:
```bash
# Test wake up (sleeping → idle)
./.claude/hooks/SessionStart

# Test thinking state
./.claude/hooks/PreToolUse

# Test working state
./.claude/hooks/PostToolUse

# Test idle state
./.claude/hooks/Stop

# Test sleep (session end)
./.claude/hooks/SessionEnd
```

## Production Setup

For production, update the environment variables:
```bash
export MASCOT_URL="https://your-mascot-app.com"
export MASCOT_TOKEN="your-secure-token-here"
```

And update `MASCOT_API_TOKEN` in your Rails app's environment.

# Automatic Sleep Detection via PID Monitoring

## Problem

ClaudeCode CLI doesn't have a built-in SessionEnd hook, so there was no way to automatically detect when the CLI closes and put the mascot to sleep.

## Solution

**Process ID (PID) Tracking** - The hooks send the claude CLI's process ID with each event. The Rails backend monitors these PIDs and automatically sleeps the mascot when all tracked processes have exited.

## How It Works

### 1. Hooks Send PID (`$PPID`)

Each hook script sends the parent process ID (claude CLI) in the webhook payload:

```bash
# In SessionStart, PreToolUse, PostToolUse, Stop hooks
-d "{\"event\":\"SessionStart\",\"timestamp\":\"...\",\"pid\":$PPID}"
```

`$PPID` is the parent process ID = the claude CLI process

### 2. Backend Tracks Active PIDs

The Rails controller (`app/controllers/api/hooks_controller.rb`) maintains a set of active PIDs:

```ruby
@@active_pids = Set.new  # Track active claude CLI process IDs

# When events arrive
pid = params[:pid]&.to_i
@@active_pids.add(pid) if pid && pid > 0
```

### 3. Background Monitor Checks Process Health

An initializer (`config/initializers/process_monitor.rb`) runs a background thread that:

- Checks every 30 seconds which PIDs are still alive
- Uses `Process.kill(0, pid)` to check without sending signals
- Removes dead PIDs from the tracking set
- When all PIDs are dead → broadcasts "sleeping" state

```ruby
Thread.new do
  loop do
    sleep 30

    # Check which PIDs are still alive
    dead_pids = active_pids.select { |pid| !process_alive?(pid) }
    dead_pids.each { |pid| active_pids.delete(pid) }

    # If all gone, sleep
    if active_pids.empty? && last_state != "sleeping"
      broadcast_sleep()
    end
  end
end
```

## Benefits

✅ **Automatic** - No user configuration required
✅ **Reliable** - Detects actual process termination
✅ **Cross-platform** - Works on any Unix-like system (macOS, Linux)
✅ **Scalable** - Works on any machine without setup
✅ **Fast detection** - Sleeps within 30 seconds of CLI exit

## Technical Details

### Why `$PPID`?

When a hook executes:
```
User's Shell (zsh/bash) - PID 1000
  └─ claude CLI - PID 1001 ← We want this!
      └─ Hook script - PID 1002 ($$)
```

- `$$` = Hook script's own PID (dies immediately, useless)
- `$PPID` = Parent PID = claude CLI (exactly what we need!)

### Process Monitoring

```ruby
def process_alive?(pid)
  Process.kill(0, pid)  # Signal 0 = check existence without sending signal
  true
rescue Errno::ESRCH  # No such process
  false
rescue Errno::EPERM  # Permission denied (process exists but different owner)
  false
end
```

### Race Conditions

- **Multiple sessions**: Each claude instance has a unique PID, tracked separately
- **Concurrent events**: PIDs stored in thread-safe Set
- **Rapid restart**: New PID immediately tracked on SessionStart

## Testing

1. Start claude CLI → Mascot wakes up
2. Use some tools → Mascot shows thinking/working/idle
3. Exit claude CLI → Within 30s, mascot sleeps automatically!

## Future Enhancements

- Make check interval configurable (currently 30s)
- Add metrics/logging for PID tracking
- Support for persisting PIDs across Rails restarts
- Windows support (different process checking mechanism)

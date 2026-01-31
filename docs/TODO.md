# Claude Mascot - TODO

A real-time Claude Code CLI companion that reflects your coding buddy's emotional state.

## Overview

Connect your Claude Code CLI to this Rails app so the mascot shows different emotions based on what Claude is doing.

## Eye States

| State | Visual | Trigger |
|-------|--------|---------|
| **Idle** | Gentle floating animation | No activity |
| **Sleeping** | Horizontal lines (closed eyes) | CLI inactive for X minutes |
| **Thinking** | Eyes looking around / pulsing | `PreToolUse` hook fired |
| **Working** | Focused eyes / fast blink | `PostToolUse` hook fired |
| **Happy** | Curved eyes (smiling) | Task completed successfully |
| **Error** | X_X eyes | Error occurred |

---

## TODO

### Phase 1: Backend Setup
- [ ] Add ActionCable to Rails app
- [ ] Create `MascotChannel` for WebSocket broadcasting
- [ ] Create `Api::HooksController` to receive Claude Code events
- [ ] Add `MascotState` model or cache to track current emotion
- [ ] Set up API authentication (simple token)

### Phase 2: Frontend Animations
- [ ] Create CSS animations for each eye state
  - [ ] Idle (gentle float) ✅
  - [ ] Sleeping (horizontal lines)
  - [ ] Thinking (looking around)
  - [ ] Working (focused blink)
  - [ ] Happy (curved smile eyes)
  - [ ] Error (X_X)
- [ ] Add JavaScript to connect to ActionCable
- [ ] Handle state transitions with smooth animations

### Phase 3: Claude Code Hooks
- [ ] Create `.claude/hooks/` directory structure
- [ ] Write `PreToolUse` hook script → sends "thinking" state
- [ ] Write `PostToolUse` hook script → sends "working" state
- [ ] Write `Stop` hook script → sends "idle" state
- [ ] Add idle timeout detection → sends "sleeping" state
- [ ] Document hook installation for users

### Phase 4: Polish
- [ ] Add sound effects (optional, toggle)
- [ ] Add dark mode support
- [ ] Make eyes responsive to screen size
- [ ] Add settings panel (animation speed, which emotions to show)
- [ ] Create install script for easy setup

---

## Technical Notes

### Claude Code Hooks Reference
- Docs: https://docs.anthropic.com/en/docs/claude-code/hooks
- Events: `PreToolUse`, `PostToolUse`, `Stop`, `Notification`
- Hooks are shell scripts in `.claude/hooks/` or configured in `.claude/settings.json`

### API Endpoint Design
```
POST /api/hooks/event
{
  "event": "PreToolUse",
  "tool": "Bash",
  "timestamp": "2026-01-31T12:00:00Z",
  "session_id": "abc123"
}
```

### ActionCable Channel
```ruby
class MascotChannel < ApplicationCable::Channel
  def subscribed
    stream_from "mascot_state"
  end
end
```

---

## Ideas for Later
- Multiple mascot themes (different eye styles)
- Mascot talks (speech bubbles with what Claude is doing)
- Desktop widget version (Electron app)
- Browser extension that floats on any page
- Mobile app companion

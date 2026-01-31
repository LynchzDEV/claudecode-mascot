class Api::HooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :authenticate_token, except: [:status]

  # Track session state in class variable (in-memory)
  @@session_active = false
  @@last_event = nil
  @@last_state = "sleeping"
  @@last_update = Time.current
  @@active_pids = Set.new  # Track active claude CLI process IDs

  def event
    event_type = params[:event]
    tool = params[:tool]
    pid = params[:pid]&.to_i  # Get PID from hook

    # Track this PID as active
    if pid && pid > 0
      @@active_pids.add(pid)
      Rails.logger.info "[HooksController] Added PID #{pid}, active PIDs: #{@@active_pids.to_a.inspect}"
    end

    # Map events to mascot states
    state = case event_type
    when "SessionStart"
      @@session_active = true
      "idle"  # Wake up when Claude Code starts
    when "PreToolUse"
      @@session_active = true  # Any tool use means session is active
      "thinking"
    when "PostToolUse"
      @@session_active = true  # Any tool use means session is active
      "working"
    when "Stop"
      "idle"  # Return to idle when tool stops (not session end!)
    when "Error"
      @@session_active = true  # Errors happen during active sessions
      "error"
    when "SessionEnd"
      @@session_active = false
      "sleeping"  # Go to sleep when session ends
    else
      @@session_active = true  # Default: any activity means session is active
      "idle"
    end

    # Update tracking
    @@last_event = event_type
    @@last_state = state
    @@last_update = Time.current

    # Broadcast state to all connected clients
    ActionCable.server.broadcast("mascot_state", {
      state: state,
      event: event_type,
      tool: tool,
      timestamp: Time.current
    })

    render json: { status: "ok", state: state }
  end

  def status
    # Return current session state
    render json: {
      session_active: @@session_active,
      state: @@last_state,
      last_event: @@last_event,
      last_update: @@last_update
    }
  end

  private

  def authenticate_token
    token = request.headers["Authorization"]&.split(" ")&.last
    expected_token = ENV.fetch("MASCOT_API_TOKEN", "dev_token_change_me")
    
    unless token == expected_token
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end
end

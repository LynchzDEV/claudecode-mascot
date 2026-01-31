class Api::HooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :authenticate_session, except: [:status]

  def event
    event_type = params[:event]
    tool = params[:tool]

    # Map events to mascot states
    state = case event_type
    when "SessionStart"
      "idle"  # Wake up when Claude Code starts
    when "PreToolUse"
      "thinking"
    when "PostToolUse"
      "working"
    when "Stop"
      "idle"  # Return to idle when tool stops
    when "Error"
      "error"
    when "SessionEnd"
      "sleeping"  # Go to sleep when session ends
    else
      "idle"
    end

    # Update session state and broadcast to the session's channel
    @session.update_state!(state, event: event_type, tool: tool)

    render json: { status: "ok", state: state }
  end

  def status
    # Check if a token is provided
    token = extract_token
    
    if token.present?
      session = MascotSession.find_by(token: token)
      if session
        session.touch_last_seen!
        return render json: {
          session_active: session.state != 'sleeping',
          state: session.state,
          last_seen_at: session.last_seen_at,
          name: session.name
        }
      end
    end

    # No valid session - return default sleeping state
    render json: {
      session_active: false,
      state: 'sleeping',
      last_seen_at: nil,
      name: nil
    }
  end

  private

  def authenticate_session
    token = extract_token
    
    unless token.present?
      return render json: { error: "Authorization token required" }, status: :unauthorized
    end

    @session = MascotSession.find_by(token: token)
    
    unless @session
      return render json: { error: "Invalid session token" }, status: :unauthorized
    end
  end

  def extract_token
    request.headers["Authorization"]&.split(" ")&.last
  end
end

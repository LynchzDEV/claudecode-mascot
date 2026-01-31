require "zip"
require "base64"

class Api::SessionsController < ApplicationController
  skip_before_action :verify_authenticity_token

  # POST /api/sessions - Create a new session
  def create
    session = MascotSession.create!(name: params[:name])

    render json: {
      token: session.token,
      name: session.name,
      state: session.state,
      created_at: session.created_at
    }, status: :created
  end

  # GET /api/sessions/:token - Get session info
  def show
    session = find_session
    return render_not_found unless session

    session.touch_last_seen!

    render json: {
      token: session.token,
      name: session.name,
      state: session.state,
      last_seen_at: session.last_seen_at
    }
  end

  # PATCH /api/sessions/:token - Update session name
  def update
    session = find_session
    return render_not_found unless session

    session.update!(name: params[:name])

    render json: {
      token: session.token,
      name: session.name,
      state: session.state
    }
  end

  # POST /api/sessions/:token/regenerate - Regenerate token
  def regenerate
    session = find_session
    return render_not_found unless session

    session.regenerate_token!

    render json: {
      token: session.token,
      name: session.name,
      message: "Token regenerated successfully"
    }
  end

  # GET /api/sessions/:token/hooks - Download configured hook scripts
  def hooks
    session = find_session
    return render_not_found unless session

    session.touch_last_seen!
    mascot_url = request.base_url

    # Create ZIP file in memory
    zip_data = Zip::OutputStream.write_buffer do |zip|
      zip.put_next_entry("hooks/SessionStart")
      zip.write generate_hook_script("SessionStart", session.token, mascot_url)

      zip.put_next_entry("hooks/PreToolUse")
      zip.write generate_hook_script("PreToolUse", session.token, mascot_url)

      zip.put_next_entry("hooks/PostToolUse")
      zip.write generate_hook_script("PostToolUse", session.token, mascot_url)

      zip.put_next_entry("hooks/Stop")
      zip.write generate_hook_script("Stop", session.token, mascot_url)

      zip.put_next_entry("hooks/SessionEnd")
      zip.write generate_hook_script("SessionEnd", session.token, mascot_url)

      zip.put_next_entry("hooks/README.md")
      zip.write generate_readme(session.token, mascot_url)
    end

    zip_data.rewind

    send_data zip_data.read,
      type: "application/zip",
      disposition: "attachment",
      filename: "claude-mascot-hooks.zip"
  end

  # GET /install/:token - One-line curl installer
  def install
    session = find_session
    return render plain: "echo 'Error: Invalid session token'; exit 1", status: :not_found unless session

    session.touch_last_seen!
    mascot_url = request.base_url

    installer_script = generate_installer_script(session.token, mascot_url)
    render plain: installer_script, content_type: "text/plain"
  end

  private

  def find_session
    MascotSession.find_by(token: params[:token])
  end

  def render_not_found
    render json: { error: "Session not found" }, status: :not_found
  end

  def generate_hook_script(event_type, token, mascot_url)
    tool_param = event_type.include?("ToolUse") ? ',\"tool\":\"$TOOL_NAME\"' : ""

    <<~BASH
      #!/bin/bash
      # Claude Code Hook: #{event_type}
      # Auto-generated for claude.lynchz.dev

      curl -s -X POST "#{mascot_url}/api/hooks/event" \\
        -H "Content-Type: application/json" \\
        -H "Authorization: Bearer #{token}" \\
        -d "{\\"event\\":\\"#{event_type}\\"#{tool_param},\\"timestamp\\":\\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\\",\\"pid\\":$PPID}" \\
        > /dev/null 2>&1 &

      exit 0
    BASH
  end

  def generate_readme(token, mascot_url)
    <<~MD
      # Claude Code Mascot Hooks

      These hooks connect your Claude Code CLI to your mascot at #{mascot_url}

      ## Installation

      1. Copy the `hooks` folder to your Claude Code config:
         ```bash
         cp -r hooks ~/.claude/hooks
         ```

      2. Make the hooks executable:
         ```bash
         chmod +x ~/.claude/hooks/*
         ```

      3. Restart Claude Code and enjoy your mascot!

      ## Your Session Token

      Your unique session token is: `#{token}`

      Keep this private! If compromised, you can regenerate it in the settings panel.

      ## Need Help?

      Visit #{mascot_url} to manage your session.
    MD
  end

  def generate_installer_script(token, mascot_url)
    hooks = %w[SessionStart PreToolUse PostToolUse Stop SessionEnd]

    <<~BASH
      #!/bin/bash
      # Claude Code Mascot Hooks Installer
      # Generated for: #{mascot_url}

      set -e

      echo "🎭 Installing Claude Code Mascot Hooks..."
      echo ""

      # Create hooks directory
      HOOKS_DIR="$HOME/.claude/hooks"
      mkdir -p "$HOOKS_DIR"

      # Download each hook
      #{hooks.map { |hook| download_hook_command(hook, token, mascot_url) }.join("\n")}

      # Make hooks executable
      chmod +x "$HOOKS_DIR"/*

      echo ""
      echo "✅ Installation complete!"
      echo ""
      echo "Your mascot is now connected to #{mascot_url}"
      echo "Start using Claude Code and watch your mascot come to life!"
      echo ""
      echo "To uninstall: rm -rf ~/.claude/hooks"
    BASH
  end

  def download_hook_command(event_type, token, mascot_url)
    hook_content = generate_hook_script(event_type, token, mascot_url)
    # Base64 encode the hook content to safely pass it through echo
    encoded_content = Base64.strict_encode64(hook_content)

    <<~BASH.chomp
      echo "  → Installing #{event_type}..."
      echo '#{encoded_content}' | base64 -d > "$HOOKS_DIR/#{event_type}"
    BASH
  end
end

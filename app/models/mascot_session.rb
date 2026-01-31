class MascotSession < ApplicationRecord
  # Auto-generate token before validation (so it's present for validation)
  before_validation :generate_token, on: :create

  # Validations
  validates :token, presence: true, uniqueness: true
  validates :state, inclusion: { in: %w[idle thinking working sleeping happy error] }, allow_nil: true

  # Scopes
  scope :active, -> { where('last_seen_at > ?', 30.days.ago) }
  scope :stale, -> { where('last_seen_at < ?', 30.days.ago) }

  # Update last seen timestamp
  def touch_last_seen!
    update!(last_seen_at: Time.current)
  end

  # Update state and broadcast to the session's channel
  def update_state!(new_state, event: nil, tool: nil)
    update!(state: new_state, last_seen_at: Time.current)
    broadcast_state(event: event, tool: tool)
  end

  # Broadcast current state to this session's WebSocket channel
  def broadcast_state(event: nil, tool: nil)
    ActionCable.server.broadcast(channel_name, {
      state: state,
      event: event,
      tool: tool,
      timestamp: Time.current
    })
  end

  # Channel name for this session's WebSocket
  def channel_name
    "mascot_state_#{token}"
  end

  # Regenerate token (if compromised)
  def regenerate_token!
    generate_token
    save!
  end

  private

  def generate_token
    self.token = SecureRandom.uuid
  end
end

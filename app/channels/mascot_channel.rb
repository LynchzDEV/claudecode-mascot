class MascotChannel < ApplicationCable::Channel
  def subscribed
    token = params[:token]
    
    if token.present?
      # Subscribe to session-specific channel
      stream_from "mascot_state_#{token}"
      Rails.logger.info "[MascotChannel] Subscribed to session: #{token[0..7]}..."
    else
      # Reject subscription without a token
      reject
      Rails.logger.warn "[MascotChannel] Rejected subscription - no token provided"
    end
  end

  def unsubscribed
    Rails.logger.info "[MascotChannel] Client unsubscribed"
  end
end

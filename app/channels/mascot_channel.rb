class MascotChannel < ApplicationCable::Channel
  def subscribed
    stream_from "mascot_state"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end

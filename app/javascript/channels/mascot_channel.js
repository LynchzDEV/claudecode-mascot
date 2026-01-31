import consumer from "channels/consumer"

// Export a function to create the subscription with a token
// This will be called from the main script after we have a session token
window.createMascotSubscription = function (token) {
  if (!token) {
    console.warn("No session token provided, cannot subscribe to MascotChannel");
    return null;
  }

  console.log("Creating MascotChannel subscription with token:", token.substring(0, 8) + "...");

  return consumer.subscriptions.create(
    { channel: "MascotChannel", token: token },
    {
      connected() {
        console.log("Connected to MascotChannel (session-specific)");
        // Notify the UI that we're connected
        if (window.onMascotConnected) {
          window.onMascotConnected();
        }
      },

      disconnected() {
        console.log("Disconnected from MascotChannel");
        // Notify the UI that we're disconnected
        if (window.onMascotDisconnected) {
          window.onMascotDisconnected();
        }
      },

      received(data) {
        console.log("Mascot state update:", data);
        if (window.updateMascotState) {
          window.updateMascotState(data.state, data.event);
        }
      }
    }
  );
};

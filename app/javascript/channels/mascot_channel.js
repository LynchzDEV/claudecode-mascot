import consumer from "channels/consumer"

consumer.subscriptions.create("MascotChannel", {
  connected() {
    console.log("Connected to MascotChannel");
  },

  disconnected() {
    console.log("Disconnected from MascotChannel");
  },

  received(data) {
    console.log("Mascot state update:", data);
    if (window.updateMascotState) {
      window.updateMascotState(data.state, data.event);
    }
  }
});

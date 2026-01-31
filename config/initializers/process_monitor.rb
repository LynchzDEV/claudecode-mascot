# Monitor claude CLI processes and auto-sleep when they exit

# Helper to check if a process is alive (defined at module level)
module ProcessMonitor
  def self.process_alive?(pid)
    return false unless pid && pid > 0

    # Send signal 0 to check if process exists (doesn't actually send a signal)
    Process.kill(0, pid)
    true
  rescue Errno::ESRCH
    # ESRCH: No such process
    false
  rescue Errno::EPERM
    # EPERM: Operation not permitted - process exists but different owner
    # For our purposes, if we can't check it, assume it's dead
    false
  end

  def self.start_monitor
    Rails.logger.info "[ProcessMonitor] Starting background PID monitor thread"

    Thread.new do
      Rails.logger.info "[ProcessMonitor] Thread started, will check every 30 seconds"

      loop do
        sleep 10  # Check every 10 seconds (reduced for faster testing)

        message = "[ProcessMonitor] Checking PIDs at #{Time.current}"
        Rails.logger.info message
        $stdout.puts message  # Also print to stdout
        $stdout.flush

        begin
          # Access the controller's class variables
          controller = Api::HooksController

          # Get current active PIDs
          active_pids = controller.class_variable_get(:@@active_pids)
          last_state = controller.class_variable_get(:@@last_state)

          Rails.logger.info "[ProcessMonitor] Active PIDs: #{active_pids.to_a.inspect}, Last state: #{last_state}"

          # Check which PIDs are still alive
          dead_pids = active_pids.select do |pid|
            alive = ProcessMonitor.process_alive?(pid)
            Rails.logger.info "[ProcessMonitor] PID #{pid} alive: #{alive}"
            !alive
          end

          # Remove dead PIDs
          if dead_pids.any?
            Rails.logger.info "[ProcessMonitor] Found dead PIDs: #{dead_pids.inspect}"
            dead_pids.each { |pid| active_pids.delete(pid) }
          end

          # If all PIDs are dead and we're not already sleeping, go to sleep
          if active_pids.empty? && last_state != "sleeping"
            controller.class_variable_set(:@@last_state, "sleeping")
            controller.class_variable_set(:@@session_active, false)
            controller.class_variable_set(:@@last_update, Time.current)

            # Broadcast sleeping state
            ActionCable.server.broadcast("mascot_state", {
              state: "sleeping",
              event: "ProcessDeath",
              timestamp: Time.current
            })

            Rails.logger.info "[ProcessMonitor] All claude processes ended, mascot sleeping"
          end
        rescue => e
          Rails.logger.error "[ProcessMonitor] Error: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
        end
      end
    end
  end
end

Rails.application.config.after_initialize do
  ProcessMonitor.start_monitor
end

# Monitor claude CLI processes and auto-sleep when they exit
# NOTE: With multi-user sessions, PID monitoring is handled per-session
# This monitor is disabled for now as sessions are database-backed

module ProcessMonitor
  def self.process_alive?(pid)
    return false unless pid && pid > 0

    Process.kill(0, pid)
    true
  rescue Errno::ESRCH
    false
  rescue Errno::EPERM
    false
  end

  def self.start_monitor
    # Disabled for multi-user session architecture
    # Each session manages its own state via the database
    Rails.logger.info "[ProcessMonitor] Disabled - using database-backed sessions"
  end
end

Rails.application.config.after_initialize do
  ProcessMonitor.start_monitor
end

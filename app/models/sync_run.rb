class SyncRun < ApplicationRecord
  STATUSES = %w[pending running completed failed].freeze

  validates :status, inclusion: { in: STATUSES }

  scope :latest, -> { order(created_at: :desc) }

  def self.current
    latest.first
  end

  def self.running?
    where(status: %w[pending running]).where(created_at: 1.hour.ago..).exists?
  end

  def running? = status.in?(%w[pending running])
  def completed? = status == "completed"
  def failed? = status == "failed"

  def progress
    return 0 if total_count.to_i.zero?
    [ (synced_count.to_f / total_count * 100).round, 100 ].min
  end

  def start!(stage: nil)
    update!(status: "running", stage: stage, started_at: Time.current)
  end

  def finish!
    update!(status: "completed", stage: "done", finished_at: Time.current)
  end

  def fail!(message)
    update!(status: "failed", error_message: message.to_s.truncate(1000), finished_at: Time.current)
  end
end

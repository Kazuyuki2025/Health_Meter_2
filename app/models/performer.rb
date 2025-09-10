class Performer < ApplicationRecord
  has_many :performances, dependent: :destroy
  has_many :activities, through: :performances
  validates :name, presence: true

  scope :with_activity_average, -> {
    joins(performances: :activities)
      .group("performers.id")
      .select("performers.*, AVG(activities.value) as avg_activity")
      .order("avg_activity DESC")
  }

  def average_activity
    return 0 unless activities.exists?
    activities.average(:value).to_f.round(2)
  end

  # 総活動量を取得
  def total_activity
    activities.sum(:value)
  end

  def get_performance_data
    performances.includes(:video, :activities).order(created_at: :desc).map do |performance|
      next if performance.activities.blank?

      {
        performance: performance,
        activities: performance.activities.order(:category),
        average: performance.average_activity,
        video_title: performance.video.title,
        date: performance.created_at
      }
    end.compact
  end

  def calculate_overall_stats
    performance_data = get_performance_data
    return {} if performance_data.empty?

    {
      total_performances: performance_data.size,
      overall_average: average_activity,  # ← 既存メソッドを使用
      highest_activity: activities.maximum(:value),
      lowest_activity: activities.minimum(:value)
    }
  end
end

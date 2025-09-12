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
      overall_average: average_activity,
      highest_activity: activities.maximum(:value),
      lowest_activity: activities.minimum(:value)
    }
  end

  def detect_unhealthy_status
  latest_performance = performances.order(date: :desc).first
  return nil unless latest_performance

  previous_activities = Activity.joins(:performance)
                                .where(performances: { performer_id: id })
                                .where.not(performance_id: latest_performance.id)

  stats = previous_activities.group_by(&:category).transform_values do |acts|
    values = acts.map(&:value).compact # nil を除外
    next if values.empty?
    mean = values.sum.to_f / values.size
    stddev = Math.sqrt(values.map { |v| (v - mean)**2 }.sum / values.size)
    { avg_value: mean, stddev_value: stddev }
  end.compact

  activities = latest_performance.activities

  z_scores = activities.map do |activity|
    next if activity.value.nil?
    stat = stats[activity.category]
    next unless stat && stat[:stddev_value] > 0
    z_score = (activity.value - stat[:avg_value]) / stat[:stddev_value]
    { category: activity.category, z_score: z_score }
  end.compact

  low_z_count = z_scores.count { |z| z[:z_score] <= -2.0 }

  {
    latest_performance_date: latest_performance.date,
    low_z_count: low_z_count,
    total_categories: z_scores.size,
    risk_percentage: z_scores.empty? ? 0 : ((low_z_count.to_f / z_scores.size) * 100).round(1),
    z_scores: z_scores
  }
  end

  def self.get_all_performers_with_statistics
    performers = Performer.includes(performances: :activities)

    performers.map do |performer|
      stats = performer.detect_unhealthy_status

      {
        performer: performer,
        performer_id: performer.id,
        performer_name: performer.name,
        average_activity: performer.average_activity,
        total_performances: performer.performances.count,
        statistics: stats
      }
    end
  end

  def self.get_performers_with_valid_statistics
    get_all_performers_with_statistics.select { |data| data[:statistics] }
  end

  # リスク順（low_z_countが多い順）でソート
  def self.sort_by_unhealthy_risk
    get_performers_with_valid_statistics
      .sort_by { |data| data[:statistics][:low_z_count] }
      .reverse
  end
end

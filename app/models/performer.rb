class Performer < ApplicationRecord
  has_many :performances, dependent: :destroy
  has_many :activities, through: :performances
  validates :name, presence: true

  scope :with_latest_activity_average, -> {
  ranked_performances = joins(performances: :video)
    .select("performers.id as performer_id,
             performances.id as performance_id,
             videos.date as video_date,
             ROW_NUMBER() OVER (
               PARTITION BY performers.id
               ORDER BY videos.date DESC
             ) as rn")

  latest_performance_ids = from("(#{ranked_performances.to_sql}) ranked")
    .where("ranked.rn = 1")
    .select("ranked.performer_id, ranked.performance_id")

  joins("INNER JOIN (#{latest_performance_ids.to_sql}) latest_perf ON performers.id = latest_perf.performer_id")
    .joins("INNER JOIN performances ON performances.id = latest_perf.performance_id")
    .joins("INNER JOIN videos ON videos.id = performances.video_id")
    .joins("INNER JOIN activities ON activities.performance_id = performances.id")
    .group("performers.id, performers.name, videos.date")
    .select("performers.*,
             AVG(activities.value) as latest_avg_activity,
             videos.date as latest_date")
    .order("latest_avg_activity DESC")
}

  def average_activity
    return 0 unless activities.exists?
    activities.average(:value).to_f.round(2)
  end

  def total_activity
    activities.sum(:value)
  end

  def get_performance_data
    performances.includes(:video, :activities)
    .joins(:video)
    .order(Arel.sql("videos.date DESC NULLS LAST, videos.created_at DESC"))
    .map do |performance|
      next if performance.activities.blank?

      {
        performance: performance,
        activities: performance.activities.order(:category),
        average: performance.average_activity,
        video_title: performance.video.title,
        video_date: performance.video&.date,
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

  z_scores = activities.filter_map do |activity|
  stat = stats[activity.category]
  next unless activity.value && stat && stat[:stddev_value] > 0
  { category: activity.category,
    z_score: (activity.value - stat[:avg_value]) / stat[:stddev_value] }
end

  low_z_count = z_scores.count { |z| z[:z_score] <= -2.0 }

  {
    latest_performance_date: latest_performance.date,
    low_z_count: low_z_count,
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

class Performer < ApplicationRecord
  has_many :performances, dependent: :destroy
  has_many :videos, through: :performances
  has_many :activities, through: :performances

  validates :name, presence: true
  validates :height, numericality: true, allow_nil: true

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
        activities: performance.activities.order(:id),
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
  latest_performance = performances
    .joins(:video)
    .order(videos: { date: :desc }, performances: { created_at: :desc })
    .first

  return nil unless latest_performance

  # インデックスベースで過去の活動データを取得
  previous_performances = performances.where.not(id: latest_performance.id)

  # 過去のパフォーマンスから統計を計算（13種類の運動）
  stats = {}
  13.times do |index|
    values = []
    previous_performances.each do |perf|
      activity_values = perf.activities.order(:id).limit(13).pluck(:value)
      values << activity_values[index] if activity_values[index]
    end

    next if values.empty?
    mean = values.sum.to_f / values.size
    stddev = Math.sqrt(values.map { |v| (v - mean)**2 }.sum / values.size)
    stats[index] = { avg_value: mean, stddev_value: stddev }
  end

  # 最新パフォーマンスのZ-Scoreを計算
  latest_values = latest_performance.activities.order(:id).limit(13).pluck(:value)
  z_scores = []

  latest_values.each_with_index do |value, index|
    if value && stats[index] && stats[index][:stddev_value] > 0
      z_score = (value - stats[index][:avg_value]) / stats[index][:stddev_value]
      z_scores << {
        index: index,
        actual_value: value,
        average_value: stats[index][:avg_value],
        z_score: z_score
      }
    end
  end

  low_z_count = z_scores.count { |z| z[:z_score] <= -2.0 }

  {
    latest_performance_date: latest_performance.video.date,
    low_z_count: low_z_count,
    z_scores: z_scores
  }
  end

  def get_statistics_data
    stats = detect_unhealthy_status

    {
      performer: self,
      performer_id: id,
      performer_name: name,
      average_activity: average_activity,
      total_performances: performances.count,
      statistics: stats,
      z_scores: stats ? stats[:z_scores] : []
    }
  end

  def self.get_all_performers_with_statistics
    performers = Performer.includes(performances: :activities)

    performers.map do |performer|
      performer.get_statistics_data
    end
  end

  def self.get_performers_with_valid_statistics
    performers = Performer.includes(performances: :activities)

    performers.filter_map do |performer|
      data = performer.get_statistics_data
      data if data[:statistics]  # statisticsがnilでない場合のみ返す
    end
  end

  # リスク順（low_z_countが多い順）でソート
  def self.sort_by_unhealthy_risk
    get_performers_with_valid_statistics
      .sort_by { |data| data[:statistics][:low_z_count] }
      .reverse
  end
end

class Performer < ApplicationRecord
  has_many :performances, dependent: :destroy
  validates :name, presence: true

  scope :with_activity_average, -> {
    joins(performances: :activities)
      .group("performers.id")
      .select("performers.*, AVG(activities.value) as avg_activity")
      .order("avg_activity DESC")
  }

  # 平均活動量を取得
  def average_activity
    activities.average(:value) || 0
  end

  # 総活動量を取得
  def total_activity
    activities.sum(:value)
  end
end

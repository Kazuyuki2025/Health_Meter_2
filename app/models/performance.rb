class Performance < ApplicationRecord
  belongs_to :performer, optional: true
  belongs_to :video
  has_many :activities, dependent: :destroy

  def get_segment_activities
    activities.order(:category).group_by(&:category)
  end

  def get_activity_data
    {
      performer: performer,
      activities: activities.order(:category),
      average: average_activity
    }
  end

  def average_activity
    return 0 if activities.empty?
    activities.average(:value).to_f.round(2)
  end

  def total_activity
    activities.sum(:value)
  end
end

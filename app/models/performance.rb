class Performance < ApplicationRecord
  belongs_to :performer, optional: true
  belongs_to :video
  has_many :activities, dependent: :destroy

  def activity_by_index(index)
    activities.limit(13).offset(0)[index]
  end

  def all_activity_values
    activities.order(:id).limit(13).pluck(:value)
  end

  def average_activity
    return 0 if activities.empty?
    activities.average(:value).to_f.round(2)
  end

  def total_activity
    activities.sum(:value)
  end

  def activities_hash
    values = all_activity_values
    hash = {}
    Activity::ACTIVITY_TYPES.each do |key, name|
      hash[name] = values[key] || 0
    end
    hash
  end

  def get_activity_data
    activity_values = all_activity_values
    data = []

    Activity::ACTIVITY_TYPES.each do |index, name|
      value = activity_values[index]
      if value
        data << {
          index: index,
          name: name,
          value: value.round(2)
        }
      end
    end
    data
  end

  def get_segment_activities
    activity_values = all_activity_values
    segments = []

    Activity::ACTIVITY_TYPES.each do |index, name|
      value = activity_values[index] || 0
      segments << {
        segment: index + 1,
        name: name,
        value: value.round(2)
      }
    end

    segments
  end
end

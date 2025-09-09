class Activity < ApplicationRecord
  belongs_to :performance

  validates :category, presence: true
  validates :value, presence: true, numericality: true

  # 活動タイプの定義
  ACTIVITY_TYPES = {
    0 => "伸びの運動",
    1 => "腕を振って脚を曲げ伸ばす運動",
    2 => "腕を回す運動",
    3 => "胸を反らす運動",
    4 => "体を横に曲げる運動",
    5 => "体を前後に曲げる運動",
    6 => "体をねじる運動",
    7 => "腕を上下に伸ばす運動",
    8 => "体を斜め下に曲げ胸を反らす運動",
    9 => "体を回す運動",
    10 => "両脚で跳ぶ運動",
    11 => "腕を振って脚を曲げ伸ばす運動",
    12 => "深呼吸"
  }.freeze

  def self.activity_types
    ACTIVITY_TYPES
  end
end

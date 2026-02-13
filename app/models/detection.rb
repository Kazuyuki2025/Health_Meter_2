class Detection < ApplicationRecord
  belongs_to :video

  validates :frame_number, presence: true
  validates :x1, :y1, :x2, :y2, presence: true
  validates :person_id, presence: true

  # 演者情報を取得するためのヘルパーメソッド
  def performance
    Performance.find_by(video_id: video_id, person_id: person_id)
  end

  def performer
    performance&.performer
  end
end

class Detection < ApplicationRecord
  belongs_to :video

  validates :frame_number, presence: true
  validates :x1, :y1, :x2, :y2, presence: true
end

class Performance < ApplicationRecord
  has_many :activities
  belongs_to :performer, optional: true
  belongs_to :video
end

class Performance < ApplicationRecord
  belongs_to :performer
  belongs_to :video
end

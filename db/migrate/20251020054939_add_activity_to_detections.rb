class AddActivityToDetections < ActiveRecord::Migration[8.0]
  def change
    add_column :detections, :activity, :float
  end
end

class AddPersonIdToDetections < ActiveRecord::Migration[8.0]
  def change
    add_column :detections, :person_id, :integer
    add_index :detections, :person_id
    add_index :detections, [ :video_id, :person_id ]
  end
end

class CreateDetections < ActiveRecord::Migration[8.0]
  def change
    create_table :detections do |t|
      t.timestamps
      t.integer :frame_number
      t.float :x1
      t.float :y1
      t.float :x2
      t.float :y2
      t.references :video, null: false, foreign_key: true
    end
  end
end

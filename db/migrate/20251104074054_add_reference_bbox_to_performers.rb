class AddReferenceBboxToPerformers < ActiveRecord::Migration[8.0]
  def change
    add_column :performers, :reference_bbox_width, :float
    add_column :performers, :reference_bbox_height, :float
    add_column :performers, :reference_bbox_size, :float
    add_column :performers, :reference_bbox_updated_at, :datetime
    add_column :performers, :reference_video_id, :integer

    add_index :performers, :reference_video_id
    add_foreign_key :performers, :videos, column: :reference_video_id
  end
end

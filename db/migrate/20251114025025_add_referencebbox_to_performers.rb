class AddReferencebboxToPerformers < ActiveRecord::Migration[8.0]
  def change
    add_column :performers, :reference_bbox_width, :float
    add_column :performers, :reference_bbox_height, :float
    add_column :performers, :reference_bbox_size, :float
  end
end

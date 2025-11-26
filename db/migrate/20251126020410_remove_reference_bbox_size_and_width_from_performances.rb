class RemoveReferenceBboxSizeAndWidthFromPerformances < ActiveRecord::Migration[7.0]
  def change
    remove_column :performances, :reference_bbox_width, :float
    remove_column :performances, :reference_bbox_size, :float
  end
end

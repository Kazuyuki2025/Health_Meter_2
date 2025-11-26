class RemoveReferenceBboxSizeAndWidthFromPerformers < ActiveRecord::Migration[8.0]
  def change
    remove_column :performers, :reference_bbox_width, :float
    remove_column :performers, :reference_bbox_size, :float
  end
end

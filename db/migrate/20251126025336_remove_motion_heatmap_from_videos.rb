class RemoveMotionHeatmapFromVideos < ActiveRecord::Migration[8.0]
  def change
    remove_column :videos, :motion_heatmap, :jsonb
  end
end

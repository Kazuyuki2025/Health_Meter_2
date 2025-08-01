class RemovepathFromVideos < ActiveRecord::Migration[8.0]
  def change
    remove_column :videos, :path
  end
end

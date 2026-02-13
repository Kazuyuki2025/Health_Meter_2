class ChangeDateToDateInVideos < ActiveRecord::Migration[8.0]
  def change
    change_column :videos, :date, :date
  end
end

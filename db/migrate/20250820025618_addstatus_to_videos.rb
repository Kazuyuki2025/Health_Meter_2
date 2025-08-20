class AddstatusToVideos < ActiveRecord::Migration[8.0]
  def change
    add_column :videos, :analysis_status, :string, default: 'pending'
    add_index :videos, :analysis_status
  end
end

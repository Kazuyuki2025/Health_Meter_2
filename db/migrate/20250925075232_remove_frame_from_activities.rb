class RemoveFrameFromActivities < ActiveRecord::Migration[8.0]
  def change
    remove_column :activities, :start_frame, :integer
    remove_column :activities, :end_frame, :integer
  end
end

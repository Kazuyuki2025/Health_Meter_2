class AddStartFrameAndEndFrameToActivities < ActiveRecord::Migration[8.0]
  def change
    add_column :activities, :start_frame, :integer
    add_column :activities, :end_frame, :integer
  end
end

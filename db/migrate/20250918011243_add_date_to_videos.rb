class AddDateToVideos < ActiveRecord::Migration[8.0]
  def change
    add_column :videos, :date, :string
  end
end

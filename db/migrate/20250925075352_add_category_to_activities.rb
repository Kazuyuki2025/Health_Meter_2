class AddCategoryToActivities < ActiveRecord::Migration[8.0]
  def change
    add_column :activities, :category, :integer
  end
end

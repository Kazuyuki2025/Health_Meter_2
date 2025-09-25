class RemoveDuplicateCategoryFromActivities < ActiveRecord::Migration[8.0]
  def change
    remove_column :activities, :category, :integer
  end
end

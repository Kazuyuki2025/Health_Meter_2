class RemoveNumFromPerformers < ActiveRecord::Migration[8.0]
  def change
    remove_column :performers, :num, :integer
  end
end

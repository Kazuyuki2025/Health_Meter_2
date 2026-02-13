class AddHeighToPerformers < ActiveRecord::Migration[8.0]
  def change
    add_column :performers, :height, :float
  end
end

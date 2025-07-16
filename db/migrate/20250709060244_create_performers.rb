class CreatePerformers < ActiveRecord::Migration[8.0]
  def change
    create_table :performers do |t|
      t.integer :num
      t.string :name

      t.timestamps
    end
  end
end

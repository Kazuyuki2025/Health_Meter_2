class CreateActivities < ActiveRecord::Migration[8.0]
  def change
    create_table :activities do |t|
      t.references :performance, null: false, foreign_key: true
      t.integer :category
      t.float :value

      t.timestamps
    end
  end
end

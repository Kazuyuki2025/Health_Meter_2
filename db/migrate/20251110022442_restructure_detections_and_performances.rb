class RestructureDetectionsAndPerformances < ActiveRecord::Migration[8.0]
  def change
    # performancesにperson_idを追加
    add_column :performances, :person_id, :integer
    add_index :performances, [ :video_id, :person_id ], unique: true

    # 既存データの移行: detections.performance_id → performances.person_id
    reversible do |dir|
      dir.up do
        # performance_idごとにperson_idを集計して設定
        execute <<-SQL
          UPDATE performances
          SET person_id = (
            SELECT person_id#{' '}
            FROM detections#{' '}
            WHERE detections.performance_id = performances.id
            AND detections.person_id IS NOT NULL
            ORDER BY detections.id
            LIMIT 1
          )
          WHERE EXISTS (
            SELECT 1 FROM detections#{' '}
            WHERE detections.performance_id = performances.id
          )
        SQL
      end
    end

    # detectionsからperformance_idを削除
    remove_index :detections, name: "index_detections_on_performance_id"
    remove_foreign_key :detections, :performances
    remove_column :detections, :performance_id, :integer
  end
end

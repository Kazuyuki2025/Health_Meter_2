class MoveBboxReferenceToPerformances < ActiveRecord::Migration[8.0]
  def change
    # performancesに基準BBox情報を追加
    add_column :performances, :reference_bbox_width, :float
    add_column :performances, :reference_bbox_height, :float
    add_column :performances, :reference_bbox_size, :float
    add_column :performances, :reference_bbox_updated_at, :datetime

    # 既存データの移行
    reversible do |dir|
      dir.up do
        # reference_video_idが設定されているperformancesにのみデータをコピー
        execute <<-SQL
          UPDATE performances
          SET#{' '}
            reference_bbox_width = (
              SELECT reference_bbox_width#{' '}
              FROM performers#{' '}
              WHERE performers.id = performances.performer_id
            ),
            reference_bbox_height = (
              SELECT reference_bbox_height#{' '}
              FROM performers#{' '}
              WHERE performers.id = performances.performer_id
            ),
            reference_bbox_size = (
              SELECT reference_bbox_size#{' '}
              FROM performers#{' '}
              WHERE performers.id = performances.performer_id
            ),
            reference_bbox_updated_at = (
              SELECT reference_bbox_updated_at#{' '}
              FROM performers#{' '}
              WHERE performers.id = performances.performer_id
            )
          WHERE EXISTS (
            SELECT 1 FROM performers#{' '}
            WHERE performers.id = performances.performer_id
            AND performers.reference_video_id = performances.video_id
          )
        SQL
      end
    end

    # performersから基準BBox情報を削除
    remove_index :performers, name: "index_performers_on_reference_video_id"
    remove_column :performers, :reference_bbox_width, :float
    remove_column :performers, :reference_bbox_height, :float
    remove_column :performers, :reference_bbox_size, :float
    remove_column :performers, :reference_bbox_updated_at, :datetime
    remove_column :performers, :reference_video_id, :integer
  end
end

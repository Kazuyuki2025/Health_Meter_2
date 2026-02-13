class ChangeAnalysisStatusToInteger < ActiveRecord::Migration[8.0]
  def up
    # 既存のstring値を数値にマップ
    execute <<-SQL
      UPDATE videos#{' '}
      SET analysis_status = CASE#{' '}
        WHEN analysis_status = 'pending' THEN '0'
        WHEN analysis_status = 'analyzing' THEN '1'
        WHEN analysis_status = 'completed' THEN '2'
        WHEN analysis_status = 'failed' THEN '3'
        ELSE '0'
      END
    SQL

    # string から integer に変更
    change_column :videos, :analysis_status, :integer, using: 'analysis_status::integer', default: 0
  end

  def down
    # integer から string に戻す
    change_column :videos, :analysis_status, :string, default: 'pending'

    execute <<-SQL
      UPDATE videos#{' '}
      SET analysis_status = CASE#{' '}
        WHEN analysis_status = '0' THEN 'pending'
        WHEN analysis_status = '1' THEN 'analyzing'
        WHEN analysis_status = '2' THEN 'completed'
        WHEN analysis_status = '3' THEN 'failed'
        ELSE 'pending'
      END
    SQL
  end
end

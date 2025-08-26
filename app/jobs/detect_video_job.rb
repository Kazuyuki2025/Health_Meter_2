require "open3"
require "shellwords"

class DetectVideoJob < ApplicationJob
  queue_as :default

  def perform(video_id)
    video = Video.find(video_id)

    if Video.where(analysis_status: "analyzing").where.not(id: video.id).exists?
      Rails.logger.info "他の動画が解析中です。2分後に再実行します。"
      self.class.set(wait: 2.minutes).perform_later(video_id)
      return
    end

    video.update!(analysis_status: "analyzing")

    begin
      video_path = ActiveStorage::Blob.service.send(:path_for, video.video_content.key)
      script_path = Rails.root.join("app/controllers/python/detect_video.py")

      Rails.logger.info "DetectVideoJob 実行開始"
      Rails.logger.info "動画パス: #{video_path}"
      Rails.logger.info "スクリプトパス: #{script_path}"

      command = "python3 #{script_path} #{Shellwords.escape(video_path)}"
      stdout, stderr, status = Open3.capture3(command)

      Rails.logger.info "DetectVideoJob stdout size=#{stdout.bytesize}"
      Rails.logger.error "DetectVideoJob stderr:\n#{stderr}" unless stderr.blank?

      if status.success?
        # JSON結果を抽出
        json_line = stdout.lines.reverse.find { |line|
          line.strip.start_with?("{") && line.include?('"averaged_results"')
        }

        if json_line
          parsed_data = JSON.parse(json_line.strip)
          save_to_activities(video, parsed_data)
          video.update!(analysis_status: "completed")
          Rails.logger.info "解析結果をActivityテーブルに保存しました: video_id=#{video.id}"
        else
          Rails.logger.error "JSON結果が見つかりません"
          video.update!(analysis_status: "failed")
        end
      else
        Rails.logger.error "Python script failed: #{stderr}"
        video.update!(analysis_status: "failed")
      end

    rescue => e
      Rails.logger.error "DetectVideoJob エラー: #{e.message}"
      video.update!(analysis_status: "failed")
      raise e
    end
  end

  private

  def save_to_activities(video, data)
    # 既存のActivityデータを削除（再解析時のため）
    video.performances.each { |p| p.activities.destroy_all }

    averaged_results = data["averaged_results"] || {}

    averaged_results.each do |person_id, segment_values|
      # Performanceレコードを作成または取得
      performance = video.performances.find_or_create_by!(
        performer_id: 1
      ) { |p| p.date = Date.current.to_s }

      # 各セグメントの値をActivityとして保存
      segment_values.each_with_index do |value, segment_index|
        Activity.create!(
          performance: performance,
          category: segment_index,  # セグメント番号をcategoryに
          value: value.to_f
        )
      end

      Rails.logger.info "Person #{person_id}: #{segment_values.size}個のセグメントをActivityに保存"
    end
  end
end

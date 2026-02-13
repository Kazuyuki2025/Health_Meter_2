require "open3"
require "shellwords"

class DetectVideoJob < ApplicationJob
  queue_as :default

  def perform(video_id)
    video = Video.find(video_id)

    unless video.performances.exists?
      Rails.logger.error "演者の紐付けが完了していません: video_id=#{video_id}"
      video.update!(analysis_status: "failed")
      return
    end

    if Video.where(analysis_status: "analyzing").where.not(id: video.id).exists?
      Rails.logger.info "他の動画が解析中です。2分後に再実行します。"
      self.class.set(wait: 2.minutes).perform_later(video_id)
      return
    end

    video.update!(analysis_status: "analyzing")

    begin
      video_path = ActiveStorage::Blob.service.send(:path_for, video.content.key)
      script_path = Rails.root.join("app/controllers/python/detect_video.py")

      Rails.logger.info "DetectVideoJob 実行開始"
      Rails.logger.info "動画パス: #{video_path}"
      Rails.logger.info "スクリプトパス: #{script_path}"

      # === 全体解析開始時間 ===
      analysis_start_time = Time.current
      Rails.logger.info "解析開始時間: #{analysis_start_time.strftime('%H:%M:%S.%3N')}"

      # === Python検出処理時間 ===
      python_start_time = Time.current
      command = "python3 #{script_path} #{Shellwords.escape(video_path)}"
      stdout, stderr, status = Open3.capture3(command)
      python_end_time = Time.current
      python_processing_time = python_end_time - python_start_time

      Rails.logger.info "Python検出処理時間: #{python_processing_time.round(3)}秒"
      Rails.logger.info "DetectVideoJob stdout size=#{stdout.bytesize}"
      Rails.logger.error "DetectVideoJob stderr:\n#{stderr}" unless stderr.blank?

      if status.success?
        json_line = stdout.lines.reverse.find { |line|
          stripped_line = line.strip
          stripped_line.start_with?("{") && stripped_line.include?('"frame_detections"')
        }

        Rails.logger.info "以下のJSONが返却されました: #{json_line}"

        if json_line
          parsed_data = JSON.parse(json_line.strip)
          Rails.logger.info "フレーム検出データ: #{parsed_data['frame_detections']&.size}件"

          # === Detection保存時間 ===
          save_start_time = Time.current
          save_to_detections(video, parsed_data)
          save_end_time = Time.current
          save_processing_time = save_end_time - save_start_time
          Rails.logger.info "Detection保存時間: #{save_processing_time.round(3)}秒"

          # === 活動量計算時間 ===
          activity_start_time = Time.current
          Rails.logger.info "活動量計算開始: #{activity_start_time.strftime('%H:%M:%S.%3N')}"

          calculate_service = CalculateActivity.new(video)
          result = calculate_service.calculate_and_save!

          activity_end_time = Time.current
          activity_processing_time = activity_end_time - activity_start_time
          Rails.logger.info "活動量計算時間: #{activity_processing_time.round(3)}秒"

          video.update!(analysis_status: "completed")
          Rails.logger.info "解析と活動量計算が完了しました: video_id=#{video.id}"

          # === 全体解析終了時間 ===
          analysis_end_time = Time.current
          total_analysis_time = analysis_end_time - analysis_start_time

          Rails.logger.info "解析終了時間: #{analysis_end_time.strftime('%H:%M:%S.%3N')}"
          Rails.logger.info "=== 詳細時間内訳 ==="
          Rails.logger.info "  Python検出処理: #{python_processing_time.round(3)}秒 (#{(python_processing_time/total_analysis_time*100).round(1)}%)"
          Rails.logger.info "  Detection保存: #{save_processing_time.round(3)}秒 (#{(save_processing_time/total_analysis_time*100).round(1)}%)"
          Rails.logger.info "  活動量計算: #{activity_processing_time.round(3)}秒 (#{(activity_processing_time/total_analysis_time*100).round(1)}%)"
          Rails.logger.info "  総解析時間: #{total_analysis_time.round(3)}秒"
          Rails.logger.info "  処理速度: #{(parsed_data['frame_detections']&.size || 0) / total_analysis_time}件/秒"
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
      Rails.logger.error e.backtrace.join("\n")
      video.update!(analysis_status: "failed")
      raise e
    end
  end

  private

  def save_to_detections(video, data)
    frame_detections = data["frame_detections"] || []

    if frame_detections.empty?
      Rails.logger.warn "フレーム検出データがありません"
      return
    end

    Rails.logger.info "Detection保存処理開始: #{frame_detections.size}件のフレームデータ"

    # 既存のDetectionデータを削除
    video.detections.destroy_all
    Rails.logger.info "既存のDetectionデータを削除しました"

    # データを一括挿入用に変換
    detections_data = frame_detections.map do |detection|
      {
        video_id: video.id,
        frame_number: detection["frame_number"],
        person_id: detection["person_id"],
        x1: detection["x1"].to_f,
        y1: detection["y1"].to_f,
        x2: detection["x2"].to_f,
        y2: detection["y2"].to_f,
        activity: detection["activity_value"].to_f,
        created_at: Time.current,
        updated_at: Time.current
      }
    end

    # 一括挿入
    begin
      Detection.insert_all(detections_data)
      Rails.logger.info "#{detections_data.size}件のDetectionデータを保存しました"

      # 統計情報
      person_ids = frame_detections.map { |d| d["person_id"] }.uniq.sort
      Rails.logger.info "検出された人物ID: #{person_ids}"

      person_ids.each do |person_id|
        count = frame_detections.count { |d| d["person_id"] == person_id }
        Rails.logger.info "  Person #{person_id}: #{count}フレーム"
      end

    rescue => e
      Rails.logger.error "Detection一括挿入エラー: #{e.message}"
      raise e
    end
  end
end

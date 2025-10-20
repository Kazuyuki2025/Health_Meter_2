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

      command = "python3 #{script_path} --segments 13 #{Shellwords.escape(video_path)}"
      stdout, stderr, status = Open3.capture3(command)

      Rails.logger.info "DetectVideoJob stdout size=#{stdout.bytesize}"
      Rails.logger.error "DetectVideoJob stderr:\n#{stderr}" unless stderr.blank?

      if status.success?
        json_line = stdout.lines.reverse.find { |line|
          stripped_line = line.strip
          stripped_line.start_with?("{") && (
            stripped_line.include?('"averaged_results"') ||
            stripped_line.include?('"frame_information"')
          )
        }

        if json_line
          parsed_data = JSON.parse(json_line.strip)

          Rails.logger.info "解析設定: #{parsed_data.dig('analysis_config', 'segments')}分割"
          Rails.logger.info "フレーム情報: #{parsed_data['frame_information']&.keys&.size}人分"
          Rails.logger.info "フレーム検出データ: #{parsed_data['frame_detections']&.size}件"

          # Activityデータを保存
          save_to_activities(video, parsed_data)

          # Detectionデータを保存（既存スキーマ対応）
          save_to_detections(video, parsed_data)

          video.update!(analysis_status: "completed")
          Rails.logger.info "解析結果をActivityとDetectionテーブルに保存しました: video_id=#{video.id}"
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

  def save_to_activities(video, data)
    video.performances.each { |p| p.activities.destroy_all }

    averaged_results = data["averaged_results"] || {}
    frame_information = data["frame_information"] || {}

    Rails.logger.info "Activity保存処理開始: #{averaged_results.keys.size}人分のデータ"

    existing_performances = video.performances.includes(:performer).to_a
    averaged_results.each_with_index do |(person_id, segment_values), index|
      performance = existing_performances[index]

      if performance.nil?
        Rails.logger.warn "Performance not found for person_id: #{person_id}, index: #{index}"
        next
      end

      Rails.logger.info "演者 #{performance.performer&.name || 'Unknown'} のデータを保存中: #{segment_values.size}セグメント"

      segment_values.each_with_index do |value, segment_index|
        frame_info = frame_information[person_id]&.[](segment_index) || {}

        Activity.create!(
          performance: performance,
          value: value,
          start_frame: frame_info["start_frame"],
          end_frame: frame_info["end_frame"]
        )
      end

      Rails.logger.info "演者 #{performance.performer&.name} の保存完了: #{segment_values.size}個のActivity"
    end

    Rails.logger.info "全Activityデータの保存完了"
  end

  # 既存スキーマ対応版（person_idなし）
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

    # データを一括挿入用に変換（既存スキーマに合わせる）
    detections_data = frame_detections.map do |detection|
      {
        video_id: video.id,
        frame_number: detection["frame_number"],
        x1: detection["x1"].to_f,
        y1: detection["y1"].to_f,
        x2: detection["x2"].to_f,
        y2: detection["y2"].to_f,
        activity: detection["activity_value"].to_f,  # activityカラムに保存
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

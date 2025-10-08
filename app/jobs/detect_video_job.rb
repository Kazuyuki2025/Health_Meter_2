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

      # 13分割を明示的に指定
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

          # データ構造をログ出力
          Rails.logger.info "解析設定: #{parsed_data.dig('analysis_config', 'segments')}分割"
          Rails.logger.info "フレーム情報: #{parsed_data['frame_information']&.keys&.size}人分"

          save_to_activities(video, parsed_data)
          video.update!(analysis_status: "completed")
          Rails.logger.info "解析結果をActivityテーブルに保存しました: video_id=#{video.id}"
        else
          Rails.logger.error "JSON結果が見つかりません"
          Rails.logger.info "stdout内容: #{stdout}"
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
    frame_information = data["frame_information"] || {}
    analysis_config = data["analysis_config"] || {}

    Rails.logger.info "保存処理開始: #{averaged_results.keys.size}人分のデータ"
    Rails.logger.info "#{analysis_config['segments']}分割"

    existing_performances = video.performances.includes(:performer).to_a

    averaged_results.each_with_index do |(person_id, segment_values), index|
      # 既存のPerformanceを使用（演者は既に紐付け済み）
      performance = existing_performances[index]

      if performance.nil?
        Rails.logger.warn "Performance not found for person_id: #{person_id}, index: #{index}"
        next
      end

      Rails.logger.info "演者 #{performance.performer&.name || 'Unknown'} のデータを保存中: #{segment_values.size}セグメント"

      # 各セグメントの値をActivityとして保存（フレーム情報付き）
      segment_values.each_with_index do |value, segment_index|
        # 対応するフレーム情報を取得
        frame_info = frame_information[person_id]&.[](segment_index) || {}

        activity = Activity.create!(
          performance: performance,
          value: value,
          start_frame: frame_info["start_frame"],
          end_frame: frame_info["end_frame"]
        )

        Rails.logger.debug "Activity ID #{activity.id}: フレーム#{frame_info['start_frame']}-#{frame_info['end_frame']}, 値: #{value}"
      end

      Rails.logger.info "演者 #{performance.performer&.name} の保存完了: #{segment_values.size}個のActivity"
    end

    Rails.logger.info "全データの保存完了"
  end
end

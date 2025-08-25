class DetectVideoJob < ApplicationJob
  queue_as :default

  def perform(video_id)
    video = Video.find(video_id)

    if Video.where(analysis_status: "analyzing").exists?
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
      success = system(command)

      if success
        Rails.logger.info "動画解析成功"
        video.update!(analysis_status: :completed)
      else
        Rails.logger.error "動画解析失敗"
        video.update!(analysis_status: :failed)
      end

    rescue => e
      Rails.logger.error "DetectVideoJob エラー: #{e.message}"
      video.update!(analysis_status: :failed)
      raise e
    end
  end
end

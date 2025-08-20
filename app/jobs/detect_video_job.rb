class DetectVideoJob < ApplicationJob
  queue_as :default

  def perform(video_id)
    if video.analyzing.exists?
      Rails.logger.info "他の動画が解析中です．1分後に再実行します．"
      self.class.set(wait: 1.minute).perform_later(video_id)
      return
    end

    video.update!(analysis_status: "analyzing")

    begin

    video = Video.find(video_id)
    video_path = ActiveStorage::Blob.service.send(:path_for, video.video_file.key)
    script_path = Rails.root.join("app/controllers/python/detect_video.py")

    Rails.logger.info "DetectVideoJob 実行開始"
    Rails.logger.info "動画パス: #{video_path}"
    Rails.logger.info "スクリプトパス: #{script_path}"

    command = "python3 #{script_path} #{Shellwords.escape(video_path)}"
    success = system(command)

      if success
        Rails.logger.info "動画解析成功"
        # video.update!(status: "detected")
        # VideoMailer.detect_complete(video).deliver_later
      else
        Rails.logger.error "動画解析失敗"
        # video.update!(status: "failed")
      end
    end
  end
end

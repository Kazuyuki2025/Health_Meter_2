require "open3"
require "shellwords"

module VideoAnalysisModule
  extend ActiveSupport::Concern

  private

  def analyze_first_frame
    video_path = ActiveStorage::Blob.service.send(:path_for, video.content.key)
    script_path = Rails.root.join("app/controllers/python/extract_frames.py")

    command = "python3 #{script_path} #{video.id} #{Shellwords.escape(video_path)}"
    Rails.logger.info "解析コマンド実行: #{command}"
    
    @stdout, @stderr, @status = Open3.capture3(command)
    
    Rails.logger.info "解析結果 - stdout: #{@stdout}"
    Rails.logger.error "解析結果 - stderr: #{@stderr}" if @stderr.present?
  end

  def parse_analysis_result(stdout)
    lines = stdout.strip.split("\n")
    ids_line = lines.first || ""
    thumbnail_path_line = lines.find { |line| line.start_with?("THUMBNAIL_PATH:") }

    detected_ids = ids_line.empty? ? [] : ids_line.split(",").map(&:to_i)

    { detected_ids: detected_ids, thumbnail_path_line: thumbnail_path_line }
  end

  def handle_analysis_failure
    @detected_ids = []
    @thumbnail_path_line = nil
  end

  def attach_thumbnail_from_analysis
    return unless @thumbnail_path_line

    thumbnail_path = @thumbnail_path_line.sub("THUMBNAIL_PATH:", "").strip
    if File.exist?(thumbnail_path)
      # 既存のサムネイルを削除してから新しいものを添付
      video.thumbnail.purge if video.thumbnail.attached?
      video.attach_thumbnail_from_file(thumbnail_path)
      Rails.logger.info "サムネイル添付完了: #{thumbnail_path}"
    else
      Rails.logger.warn "サムネイルファイルが見つかりません: #{thumbnail_path}"
    end
  end

  def get_generated_images
    return [] unless video.thumbnail.attached?
    [ video.thumbnail_url ]
  end

  def perform_analysis
    analyze_first_frame
    
    if @status.success?
      result = parse_analysis_result(@stdout)
      @detected_ids = result[:detected_ids]
      @thumbnail_path_line = result[:thumbnail_path_line]
      
      attach_thumbnail_from_analysis
      true
    else
      Rails.logger.error("Python Error: #{@stderr}")
      handle_analysis_failure
      false
    end
  end

  def success_result(notice_msg = nil)
    VideoUploadResult.new(
      success: true,
      video: video,
      shooting_date: video.date,
      detected_ids: @detected_ids || [],
      images: @images || [],
      notice_msg: notice_msg || default_success_message
    )
  end

  def failure_result(message)
    VideoUploadResult.new(
      success: false,
      error_message: message,
      video: video,
      shooting_date: video.date
    )
  end

  def default_success_message
    if @detected_ids&.any?
      "解析が完了しました。#{@detected_ids.size} 人を検出しました。"
    else
      "解析が完了しましたが、顔を検出できませんでした。"
    end
  end
end

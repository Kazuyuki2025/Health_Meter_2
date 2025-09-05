require "open3"
require "shellwords"

class VideoUploadService
  include ActiveModel::Model

  attr_accessor :video_params, :uploaded_file

  def initialize(video_params:, uploaded_file:)
    @video_params = video_params
    @uploaded_file = uploaded_file
    @video = Video.new(video_params)
  end

  def call
    return failure("ファイルが選択されていません") unless uploaded_file
    return failure("動画パラメータが不正です") unless video_params.present?

    process_video_upload
  end

  private

  attr_reader :video, :video_params, :uploaded_file

  def process_video_upload
    attach_and_prepare_video

    if video.save
      analyze_first_frame
      if @status.success?
        result = parse_analysis_result(@stdout)
        @detected_ids = result[:detected_ids]
        @thumbnail_path_line = result[:thumbnail_path_line]
      else
        Rails.logger.error("Python Error: #{@stderr}")
        handle_analysis_failure
      end
      attach_thumbnail_from_analysis
      prepare_response_data
      success
    else
      failure("動画の保存に失敗しました: #{video.errors.full_messages.join(', ')}")
    end
  rescue => e
    Rails.logger.error "エラー発生: #{e.message}"
    failure("アップロード中にエラーが発生しました")
  end

  def attach_and_prepare_video
    temp_path = uploaded_file.tempfile.path
    movie = FFMPEG::Movie.new(temp_path)

    attach_source_path = temp_path
    transcoded = false

    unless movie.video_codec == "h264"
      h264_path = temp_path + "_h264.mp4"
      movie.transcode(h264_path, %w[-vcodec libx264 -acodec aac -movflags +faststart])
      attach_source_path = h264_path
      transcoded = true
    end

    video.content.attach(
      io: File.open(attach_source_path),
      filename: uploaded_file.original_filename,
      content_type: "video/mp4"
    )

    FileUtils.rm_f(attach_source_path) if transcoded && File.exist?(attach_source_path)
  end

  def analyze_first_frame
    video_path = ActiveStorage::Blob.service.send(:path_for, video.content.key)
    script_path = Rails.root.join("app/controllers/python/extract_frames.py")

    command = "python3 #{script_path} #{video.id} #{Shellwords.escape(video_path)}"
    @stdout, @stderr, @status = Open3.capture3(command)
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
      video.attach_thumbnail_from_file(thumbnail_path)
      Rails.logger.info "Thumbnail attached from: #{thumbnail_path}"
    else
      Rails.logger.warn "Thumbnail file not found: #{thumbnail_path}"
    end
  end

  def prepare_response_data
    @notice_msg = if @detected_ids&.any?
      "動画がアップロードされました。画像解析で #{@detected_ids.size} 人を検出しました。"
    else
      "動画がアップロードされましたが、画像解析に失敗しました。"
    end

    @images = get_generated_images
  end

  def get_generated_images
    return [] unless video.thumbnail.attached?
    [ video.thumbnail_url ]
  end

  def success
    VideoUploadResult.new(
      success: true,
      video: video,
      detected_ids: @detected_ids || [],
      images: @images || [],
      notice_msg: @notice_msg || "動画がアップロードされました"
    )
  end

  def failure(message)
    VideoUploadResult.new(
      success: false,
      error_message: message,
      video: video
    )
  end
end

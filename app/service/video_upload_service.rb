require "open3"
require "shellwords"

class VideoUploadService
  include ActiveModel::Model
  include VideoAnalysisModule

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
      if perform_analysis
        prepare_response_data
        success_result(@notice_msg)
      else
        failure_result("画像解析に失敗しました: #{@stderr}")
      end
    else
      failure_result("動画の保存に失敗しました: #{video.errors.full_messages.join(', ')}")
    end
  rescue => e
    Rails.logger.error "エラー発生: #{e.message}"
    failure_result("アップロード中にエラーが発生しました")
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

  def prepare_response_data
    @notice_msg = if @detected_ids&.any?
      "動画がアップロードされました。画像解析で #{@detected_ids.size} 人を検出しました。"
    else
      "動画がアップロードされましたが、画像解析に失敗しました。"
    end

    @images = get_generated_images
  end
end

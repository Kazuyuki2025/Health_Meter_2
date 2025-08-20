require "ostruct"

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

    process_video_upload
  end

  private

  attr_reader :video, :video_params, :uploaded_file

  def process_video_upload
    attach_video_file

    if video.save
      analyze_first_frame
      start_video_analysis
      success
    else
      failure("動画の保存に失敗しました")
    end
  rescue => e
    Rails.logger.error "エラー発生: #{e.message}"
    failure("アップロード中にエラーが発生しました")
  end

  def attach_video_file
    temp_path = uploaded_file.tempfile.path
    movie = FFMPEG::Movie.new(temp_path)

    if movie.video_codec != "h264"
      convert_and_attach_h264(temp_path, movie)
    else
      attach_original_file(temp_path)
    end
  end

  def convert_and_attach_h264(temp_path, movie)
    h264_path = temp_path + "_h264.mp4"
    movie.transcode(h264_path, %w[-vcodec libx264 -acodec aac -movflags +faststart])

    video.video_file.attach(
      io: File.open(h264_path),
      filename: uploaded_file.original_filename,
      content_type: "video/mp4"
    )

    FileUtils.rm(h264_path) if File.exist?(h264_path)
  end

  def attach_original_file(temp_path)
    video.video_file.attach(
      io: File.open(temp_path),
      filename: uploaded_file.original_filename,
      content_type: "video/mp4"
    )
  end

  def analyze_first_frame
    # video.video_file.blob.analyze unless video.video_file.blob.analyzed?

    video_path = ActiveStorage::Blob.service.send(:path_for, video.video_file.key)
    script_path = Rails.root.join("app/controllers/python/extract_fases.py")
    command = "python3 #{script_path} #{video.id} #{Shellwords.escape(video_path)}"

    stdout, stderr, status = Open3.capture3(command)

    if status.success?
      result = stdout.strip.split("\n").last
      @detected_ids = result.split(",").map(&:to_i)
      @notice_msg = "動画がアップロードされました。画像解析で #{@detected_ids.size} 人を検出しました。"
    else
      Rails.logger.error("Python Error: #{stderr}")
      @detected_ids = []
      @notice_msg = "動画がアップロードされましたが、画像解析に失敗しました。"
    end

    @images = get_generated_images
  end

  def get_generated_images
    image_dir = "/first_frame/video_id_#{video.id}"
    Dir.glob(Rails.root.join("public", "first_frame", "video_id_#{video.id}", "*.jpg")).map do |img|
      File.join(image_dir, File.basename(img))
    end
  end

  def start_video_analysis
    Rails.logger.info "\n\n\n\n動画解析開始\n\n\n\n"
    DetectVideoJob.perform_later(video.id)
  end

  def success
    OpenStruct.new(
      success?: true,
      video: video,
      detected_ids: @detected_ids || [],
      images: @images || [],
      notice_msg: @notice_msg || "動画がアップロードされました"
    )
  end

  def failure(message)
    OpenStruct.new(
      success?: false,
      error_message: message,
      video: video
    )
  end
end

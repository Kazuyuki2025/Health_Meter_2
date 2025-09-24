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
    extract_video_metadata
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

  def extract_video_metadata
    temp_path = uploaded_file.tempfile.path
    movie = FFMPEG::Movie.new(temp_path)

    # 撮影日時を取得
    shooting_date = extract_video_creation_date(movie, temp_path)

    # Videoオブジェクトに日付を設定
    video.date = shooting_date || Date.current

    Rails.logger.info "動画撮影日: #{video.date}"
  end

  def attach_and_prepare_video
    temp_path = uploaded_file.tempfile.path
    movie = FFMPEG::Movie.new(temp_path)

    attach_source_path = temp_path
    transcoded = false

    unless movie.video_codec == "h264"
      h264_path = temp_path + "_h264.mp4"

      Rails.logger.info "H.264エンコードが必要です。CPU エンコードを開始します"
      cpu_encode(movie, h264_path)

      attach_source_path = h264_path
      transcoded = true
    else
      Rails.logger.info "エンコード不要: 既にH.264形式です"
    end

    video.content.attach(
      io: File.open(attach_source_path),
      filename: uploaded_file.original_filename,
      content_type: "video/mp4"
    )

    FileUtils.rm_f(attach_source_path) if transcoded && File.exist?(attach_source_path)
  end



  def cpu_encode(movie, output_path)
    begin
      # CPU エンコード設定を動的に最適化
      cpu_options = get_optimized_cpu_options(movie)

      Rails.logger.info "CPU エンコード開始: #{File.basename(output_path)} (#{movie.width}x#{movie.height})"
      start_time = Time.current

      movie.transcode(output_path, cpu_options) do |progress|
        if progress > 0
          elapsed = Time.current - start_time
          estimated_total = elapsed / progress
          remaining = estimated_total - elapsed

          Rails.logger.debug "CPU エンコード進行: #{(progress * 100).round(1)}% (残り約#{remaining.round}秒)"
        end
      end

      elapsed_time = Time.current - start_time
      file_size_mb = File.size(output_path) / 1024.0 / 1024.0
      original_size_mb = File.size(movie.path) / 1024.0 / 1024.0
      compression_ratio = ((original_size_mb - file_size_mb) / original_size_mb * 100).round(1)

      Rails.logger.info "CPU エンコード完了 - 処理時間: #{elapsed_time.round(1)}秒, " \
                        "ファイルサイズ: #{file_size_mb.round(1)}MB " \
                        "(#{compression_ratio}% 圧縮)"

    rescue FFMPEG::Error => e
      Rails.logger.error "CPU エンコードエラー: #{e.message}"
      raise e
    end
  end

  def get_optimized_cpu_options(movie)
    # 入力動画の情報に基づいて最適化
    width = movie.width || 1920
    height = movie.height || 1080
    total_pixels = width * height

    # 解像度別の最適化設定
    case total_pixels
    when 0..518400        # ~720x720 (SD)
      preset = "fast"
      crf = "25"
      threads = 4
    when 518401..921600   # ~HD (720p)
      preset = "fast"
      crf = "24"
      threads = 6
    when 921601..2073600  # ~Full HD (1080p)
      preset = "medium"
      crf = "23"
      threads = 8
    else                  # 4K+
      preset = "slow"
      crf = "22"
      threads = 12
    end

    # CPU コア数を考慮した調整
    available_cores = Etc.nprocessors
    threads = [ threads, available_cores ].min

    Rails.logger.info "エンコード設定: #{width}x#{height} (#{total_pixels}px), " \
                      "preset: #{preset}, crf: #{crf}, threads: #{threads}"

    [
      "-c:v", "libx264",
      "-preset", preset,
      "-crf", crf,
      "-profile:v", "high",
      "-level", "4.1",
      "-threads", threads.to_s,      # スレッド数を明示的に指定
      "-tune", "film",               # 実写動画に最適化
      "-c:a", "aac",
      "-b:a", "128k",
      "-ac", "2",                    # ステレオに統一
      "-ar", "44100",                # サンプリングレートを統一
      "-movflags", "+faststart",
      "-pix_fmt", "yuv420p"          # 互換性のための色空間指定
    ]
  end

  def prepare_response_data
    @notice_msg = if @detected_ids&.any?
      "動画がアップロードされました。画像解析で #{@detected_ids.size} 人を検出しました。"
    else
      "動画がアップロードされましたが、画像解析に失敗しました。"
    end

    @images = get_generated_images
  end

  private
  def extract_video_creation_date(movie, file_path)
    # FFmpegのメタデータから撮影日時を取得
    creation_time = movie.metadata[:creation_time] ||
                  movie.metadata[:date] ||
                  movie.metadata[:com_apple_quicktime_creationdate]

    if creation_time
      begin
        return Time.parse(creation_time).to_date
      rescue => e
        Rails.logger.warn "メタデータの日時解析に失敗: #{e.message}"
      end
    end

    begin
      return File.ctime(file_path).to_date
    rescue => e
      Rails.logger.warn "ファイル作成日時の取得に失敗: #{e.message}"
    end

    # デフォルトはnil（現在日付は呼び出し元で設定）
    nil
  end
end

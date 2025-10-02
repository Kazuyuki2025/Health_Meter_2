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

    # ffprobeを使って撮影日を取得
    shooting_date = extract_shooting_date_with_ffprobe(temp_path)

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

  def extract_shooting_date_with_ffprobe(file_path)
    Rails.logger.info "=== FFprobe撮影日取得開始 ==="

    # 撮影日時関連のメタデータを取得するコマンド
    commands = [
      # QuickTime/MOV形式の撮影日時
      "ffprobe -v quiet -select_streams v:0 -show_entries stream_tags=creation_time -of csv=p=0 #{Shellwords.escape(file_path)}",

      # フォーマットレベルの撮影日時
      "ffprobe -v quiet -show_entries format_tags=creation_time -of csv=p=0 #{Shellwords.escape(file_path)}",

      # Apple QuickTime特有の撮影日時
      "ffprobe -v quiet -show_entries format_tags=com.apple.quicktime.creationdate -of csv=p=0 #{Shellwords.escape(file_path)}",

      # 一般的な日付フィールド
      "ffprobe -v quiet -show_entries format_tags=date -of csv=p=0 #{Shellwords.escape(file_path)}",

      # より詳細な撮影日時情報
      "ffprobe -v quiet -show_entries format_tags=encoded_date -of csv=p=0 #{Shellwords.escape(file_path)}"
    ]

    commands.each_with_index do |command, index|
      Rails.logger.info "コマンド #{index + 1}: #{command}"

      begin
        stdout, stderr, status = Open3.capture3(command)

        Rails.logger.info "stdout: '#{stdout.strip}'"
        Rails.logger.info "stderr: '#{stderr.strip}'" if stderr.present?
        Rails.logger.info "status: #{status.success?}"

        if status.success? && stdout.strip.present?
          date_string = stdout.strip

          Rails.logger.info "取得した日付文字列: '#{date_string}'"

          # 日付文字列を解析
          parsed_date = parse_date_string(date_string)

          if parsed_date
            Rails.logger.info "解析成功: #{parsed_date}"
            return parsed_date
          end
        end

      rescue => e
        Rails.logger.error "コマンド実行エラー: #{e.message}"
      end
    end

    # ffprobeで取得できない場合はファイル名から日付を抽出
    Rails.logger.info "ffprobeでの撮影日取得に失敗、ファイル名から日付を抽出"
    filename_date = extract_date_from_filename(uploaded_file.original_filename)

    if filename_date
      Rails.logger.info "ファイル名から日付を抽出: #{filename_date}"
      return filename_date
    end

    # ファイル名からも取得できない場合はファイル作成日時を使用
    Rails.logger.info "ファイル名からも日付抽出に失敗、ファイル作成日時を使用"
    fallback_to_file_date(file_path)
  end

  # ファイル名から日付を抽出する新しいメソッド
  def extract_date_from_filename(filename)
    return nil if filename.blank?

    Rails.logger.info "ファイル名から日付抽出開始: '#{filename}'"

    # 各種日付パターンを定義
    date_patterns = [
      # YYYY-MM-DD 形式
      /(\d{4})-(\d{1,2})-(\d{1,2})/,

      # YYYY_MM_DD 形式
      /(\d{4})_(\d{1,2})_(\d{1,2})/,

      # YYYYMMDD 形式
      /(\d{4})(\d{2})(\d{2})/,

      # YYYY/MM/DD 形式
      /(\d{4})\/(\d{1,2})\/(\d{1,2})/,

      # DD-MM-YYYY 形式
      /(\d{1,2})-(\d{1,2})-(\d{4})/,

      # DD_MM_YYYY 形式
      /(\d{1,2})_(\d{1,2})_(\d{4})/,

      # MM-DD-YYYY 形式
      /(\d{1,2})-(\d{1,2})-(\d{4})/,

      # iPhone/Android形式（IMG_20240315_123456.mp4 など）
      /(?:IMG|VID|MOV)_(\d{4})(\d{2})(\d{2})_\d+/i,

      # WhatsApp形式（VID-20240315-WA0001.mp4 など）
      /(?:VID|IMG)-(\d{4})(\d{2})(\d{2})-/i,

      # その他の一般的な形式
      /(\d{4})\.(\d{1,2})\.(\d{1,2})/,
      /(\d{1,2})\.(\d{1,2})\.(\d{4})/
    ]

    date_patterns.each_with_index do |pattern, index|
      match = filename.match(pattern)

      if match
        Rails.logger.info "パターン #{index + 1} にマッチ: #{pattern}"
        Rails.logger.info "マッチした値: #{match.captures}"

        begin
          # パターンによって年月日の順番を調整
          case index
          when 0..3, 7, 8, 10  # YYYY-MM-DD, YYYY_MM_DD, YYYYMMDD, YYYY/MM/DD, IMG_, VID-, YYYY.MM.DD 形式
            year, month, day = match.captures.map(&:to_i)
          when 4, 5, 11  # DD-MM-YYYY, DD_MM_YYYY, DD.MM.YYYY 形式
            day, month, year = match.captures.map(&:to_i)
          when 6  # MM-DD-YYYY 形式（アメリカ式）
            month, day, year = match.captures.map(&:to_i)
          else
            year, month, day = match.captures.map(&:to_i)
          end

          Rails.logger.info "解析された日付: #{year}/#{month}/#{day}"

          # 日付の妥当性をチェック
          if valid_date?(year, month, day)
            parsed_date = Date.new(year, month, day)
            Rails.logger.info "ファイル名から日付抽出成功: #{parsed_date}"
            return parsed_date
          else
            Rails.logger.warn "無効な日付: #{year}/#{month}/#{day}"
          end

        rescue ArgumentError => e
          Rails.logger.warn "日付変換エラー: #{e.message}"
        end
      end
    end

    Rails.logger.info "ファイル名から日付を抽出できませんでした"
    nil
  end

  # 日付の妥当性をチェック
  def valid_date?(year, month, day)
    return false if year < 1900 || year > Date.current.year + 1
    return false if month < 1 || month > 12
    return false if day < 1 || day > 31

    # より厳密なチェック
    begin
      Date.new(year, month, day)
      true
    rescue ArgumentError
      false
    end
  end

  # より高度なファイル名解析（オプション）
  def extract_advanced_date_from_filename(filename)
    return nil if filename.blank?

    Rails.logger.info "高度なファイル名解析: '#{filename}'"

    # よくあるファイル名形式を個別に処理
    advanced_patterns = [
      # 2024年3月15日_動画.mp4
      {
        pattern: /(\d{4})年(\d{1,2})月(\d{1,2})日/,
        order: [ :year, :month, :day ]
      },

      # 20240315_video.mp4
      {
        pattern: /^(\d{4})(\d{2})(\d{2})_/,
        order: [ :year, :month, :day ]
      },

      # video_2024-03-15.mp4
      {
        pattern: /_(\d{4})-(\d{1,2})-(\d{1,2})/,
        order: [ :year, :month, :day ]
      },

      # 15032024_video.mp4 (DD/MM/YYYY)
      {
        pattern: /^(\d{2})(\d{2})(\d{4})_/,
        order: [ :day, :month, :year ]
      }
    ]

    advanced_patterns.each do |pattern_info|
      match = filename.match(pattern_info[:pattern])

      if match
        values = match.captures.map(&:to_i)
        date_hash = {}

        pattern_info[:order].each_with_index do |key, index|
          date_hash[key] = values[index]
        end

        if valid_date?(date_hash[:year], date_hash[:month], date_hash[:day])
          parsed_date = Date.new(date_hash[:year], date_hash[:month], date_hash[:day])
          Rails.logger.info "高度な解析で日付抽出成功: #{parsed_date}"
          return parsed_date
        end
      end
    end

    nil
  end

  # デバッグ用：全メタデータを表示
  def debug_all_metadata(file_path)
    Rails.logger.info "=== 全メタデータ情報 ==="

    command = "ffprobe -v quiet -print_format json -show_format -show_streams #{Shellwords.escape(file_path)}"
    stdout, stderr, status = Open3.capture3(command)

    if status.success?
      begin
        data = JSON.parse(stdout)

        # フォーマットタグを表示
        if data["format"] && data["format"]["tags"]
          Rails.logger.info "フォーマットタグ:"
          data["format"]["tags"].each do |key, value|
            Rails.logger.info "  #{key}: #{value}"
          end
        end

        # ストリームタグを表示
        if data["streams"]
          data["streams"].each_with_index do |stream, index|
            if stream["tags"]
              Rails.logger.info "ストリーム#{index}タグ:"
              stream["tags"].each do |key, value|
                Rails.logger.info "  #{key}: #{value}"
              end
            end
          end
        end

      rescue JSON::ParserError => e
        Rails.logger.error "JSON解析エラー: #{e.message}"
      end
    else
      Rails.logger.error "ffprobeエラー: #{stderr}"
    end
  end
end

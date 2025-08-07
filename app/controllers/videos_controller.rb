require "shellwords"
require "open3"

class VideosController < ApplicationController
  def new
    @video = Video.new
  end

  def create
    begin
      @video = Video.new(video_params)

      uploaded_file = params[:video][:video_file]
      return render :new, alert: "ファイルが選択されていません" unless uploaded_file

      temp_path = uploaded_file.tempfile.path

      # デバッグ
      Rails.logger.debug "一時ファイルパス: #{temp_path}"
      Rails.logger.debug "オリジナルファイル名: #{uploaded_file.original_filename}"

      # コーデック変換
      movie = FFMPEG::Movie.new(temp_path)
      Rails.logger.info "元のコーデック: #{movie.video_codec}"

      if movie.video_codec != "h264"
        h264_path = temp_path + "_h264.mp4"
        movie.transcode(h264_path, %w[-vcodec libx264 -acodec aac -movflags +faststart])

        # 変換後のファイルを添付
        @video.video_file.attach(
          io: File.open(h264_path),
          filename: uploaded_file.original_filename,
          content_type: "video/mp4"
        )

        # 変換後の一時ファイルを削除
        FileUtils.rm(h264_path) if File.exist?(h264_path)
      else
        # H.264の場合はそのまま添付
        @video.video_file.attach(
          io: File.open(temp_path),
          filename: uploaded_file.original_filename,
          content_type: "video/mp4"
        )
      end

      if @video.save
        # redirect_to video_path, notice: "動画がアップロードされました"

        video_id = @video.id
        video_path = ActiveStorage::Blob.service.send(:path_for, @video.video_file.key)
        script_path = Rails.root.join("app/controllers/python/extract_fases.py")
        command = "python3 #{script_path} #{video_id} #{Shellwords.escape(video_path)}"

        stdout, stderr, status = Open3.capture3(command)

        if status.success?
          result = stdout.strip
          @detected_ids = result.split(",").map(&:to_i)
          notice_msg = "動画がアップロードされました。画像解析で #{@detected_ids.size} 人を検出しました。"
        else
          Rails.logger.error("Python Error: #{stderr}")
          @detected_ids = []
          notice_msg = "動画がアップロードされましたが、画像解析に失敗しました。"
        end

        image_dir = "/first_frame/#{video_id}"
        @images = Dir.glob(Rails.root.join("public", "first_frame", video_id.to_s, "*.jpg")).map do |img|
          File.join(image_dir, File.basename(img))
      end

        flash.now[:notice] = notice_msg
        Rails.logger.info "\n\n\n\n動画解析開始\n\n\n\n"
        DetectVideoJob.perform_later(@video.id)

        render :new
      else
        render :new, status: :unprocessable_entity
      end

    rescue => e
      Rails.logger.error "エラー発生: #{e.message}"
      flash.now[:alert] = "アップロード中にエラーが発生しました"
      render :new, status: :unprocessable_entity
    end
  end

  def video_params
    params.require(:video).permit(:title, :video_file)
  end

  def index
    @videos = Video.all
  end

  def show
    @video = Video.find(params[:id])
  end

  def edit
    @video = Video.find(params[:id])
  end

  def update
  @video = Video.find(params[:id])
  if @video.update(video_params)
    redirect_to videos_path, notice: "動画情報を更新しました"
  else
    render :edit, status: :unprocessable_entity
  end
  rescue ActiveRecord::RecordNotFound
  redirect_to videos_path, alert: "動画が見つかりません", status: :not_found
  end

  def destroy
    @video = Video.find(params[:id])
    @video.destroy

    redirect_to videos_path, notice: "動画を削除しました", status: :see_other
  rescue ActiveRecord::RecordNotFound
    redirect_to videos_path, alert: "動画が見つかりません", status: :not_found
  end
end

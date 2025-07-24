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
        redirect_to @video, notice: "動画がアップロードされました"
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
    params.require(:video).permit(:video_file)
  end

  def index
    @videos = Video.all
  end

  def show
    @video = Video.find(params[:id])
  end

  def destroy
    @video = Video.find(params[:id])
    @video.destroy

    redirect_to videos_path, notice: "動画を削除しました", status: :see_other
  rescue ActiveRecord::RecordNotFound
    redirect_to videos_path, alert: "動画が見つかりません", status: :not_found
  end
end

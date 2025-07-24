class VideosController < ApplicationController
  def new
    @video = Video.new
  end

  def create
    @video = Video.new
    uploaded_file = params[:video][:video_file]

    if uploaded_file.blank?
      flash[:alert] = "ファイルを選択してください"
      render :new and return
    end

    @video = Video.new(video_params)
    @video.file.attach(uploaded_file)

    if @video.file.attached?
      video_path = ActiveStorage::Blob.service.path_for(@video.file.key)
      convert_to_h264_if_needed(video_path)
    end

    # データベースに保存
    if @video.save
      flash[:notice] = "動画がアップロードされました"
      redirect_to @video
      puts "succeed---------------------------------------"
    else
      flash[:alert] = "動画のアップロード中にエラーが発生しました: #{e.message}"
      Rails.logger.error "Flash Alert: #{flash[:alert]}"
      render :new

    end
  end

  def video_params
    params.require(:video).permit(:file)
  end
  def index
    @videos = Video.all
  end

  def show
    @video = Video.find(params[:id])
  end

  def convert_to_h264_if_needed(video_path)
    movie = FFMPEG::Movie.new(video_path)
    Rails.logger.info "Movie Codec: #{movie.video_codec}"
    unless movie.video_codec == "h264"
      h264_path = video_path.to_s.sub(/\.mp4\z/, "_h264.mp4")
      movie.transcode(h264_path, %w[-vcodec libx264 -acodec aac -movflags +faststart])
      FileUtils.mv(h264_path, video_path)
    end
  end
end

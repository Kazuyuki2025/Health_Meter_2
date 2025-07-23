class VideosController < ApplicationController
  def new
    @video = Video.new
  end

  def create
    @video = Video.new(video_params)

    if params[:video][:file].blank?
      flash[:alart] = "ファイルを選択してください"
      render :new and return
    end

    @video.file.attach(io: params[:video][:path].open, filename: params[:video][:path].original_filename)

    video_path = ActiveStorage::Blob.service.path_for(@video.file.key)

    # コーデックの判定，"H.264"出でない場合は変換
    movie = FFMPEG::Movie.new(video_path)
    puts "---------------\nMovie Codec: #{movie.video_codec}\n"
    if movie.video_codec != "h264"
      h264_path = video_path.to_s.sub(/\.mp4\z/, "_h264.mp4")
      movie.transcode(h264_path, %w[-vcodec libx264 -acodec aac -movflags +faststart])
      FileUtils.mv(h264_path, video_path) # 上書き
    end

    # データベースに保存
    if @video.save
      flash[:notice] = "動画がアップロードされました"
      redirect_to @video
    else
      flash[:alert] = "動画のアップロードに失敗しました"
      render :new
    end
  end
  def index
  end

  def show
  end
end

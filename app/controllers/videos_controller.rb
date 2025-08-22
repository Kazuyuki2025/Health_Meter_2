require "shellwords"
require "open3"

class VideosController < ApplicationController
  def new
    @video = Video.new
  end

  def create
    service = VideoUploadService.new(
      video_params: video_params,
     uploaded_file: params[:video][:video_file]
    )

    result = service.call

    if result.success?
      @video = result.video
      @detected_ids = result.detected_ids
      @images = result.images
      flash.now[:notice] = result.notice_msg
      render :new
    else
      @video = result.video || Video.new
      flash.now[:alert] = result.error_message
      render :new, status: :unprocessable_entity
    end
  end

  def video_params
    params.require(:video).permit(:title, :video_file, :analysis_status)
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

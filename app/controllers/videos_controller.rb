require "open3"

class VideosController < ApplicationController
  def new
    @video = Video.new
  end


  def create
    service = VideoUploadService.new(
      video_params: video_params,
     uploaded_file: params[:video][:content]
    )

    result = service.call

    if result.success?
      @video = result.video
      @detected_ids = result.detected_ids
      @images = result.images
      @performers = Performer.all
      flash.now[:notice] = result.notice_msg
      render :new
    else
      @video = result.video || Video.new
      flash.now[:alert] = result.error_message
      render :new, status: :unprocessable_entity
    end
  end

  def assign_performers
    @video = Video.find(params[:id])

    if params[:performer_assignments].present?
      params[:performer_assignments].each do |detected_id, performer_id|
      @video.assign_performer(detected_id, performer_id)
    end

      @video.update(analysis_status: :analyzing)
      DetectVideoJob.perform_later(@video.id)

      redirect_to @video, notice: "演者の紐付けが完了しました。詳細分析を開始します。"
    else
      redirect_to @video, alert: "演者を選択してください"
    end
  end

  def reanalyze
    @video = Video.find(params[:id])

    service = VideoReanalysisService.new(video: @video)
    result = service.call

    if result.success?
      @detected_ids = result.detected_ids
      @images = result.images
      @performers = Performer.all
      flash.now[:notice] = result.notice_msg
      render :show
    else
      flash[:alert] = result.error_message
      redirect_to @video
    end
  end

  def video_params
    params.require(:video).permit(:title, :content, :analysis_status)
  end

  def index
    @videos = Video.all
  end
  def show
    @video = Video.find(params[:id])
    @performances = @video.performances.includes(:performer)

    # 活動量データの計算
    @detected_ids = @video.get_detected_ids
    @activity_data = @video.get_all_activities
    @overall_stats = @video.calculate_overall_stats
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

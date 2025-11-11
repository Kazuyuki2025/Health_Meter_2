require "open3"

class VideosController < ApplicationController
  before_action :set_video, only: [ :edit, :update, :show, :destroy, :player, :frame_data, :all_frames_data ]
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
      @shooting_date = result.shooting_date
      @detected_ids = result.detected_ids
      @images = result.images
      @performers = Performer.all
      flash.now[:notice] = result.notice_msg
      render :new
      Rails.logger.info "動画アップロード成功: 撮影日 #{result.shooting_date}"
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
      flash[:detected_ids] = result.detected_ids
      @images = result.images
      @performers = Performer.all
      redirect_to @video, notice: "再解析を開始します。演者を紐付けてください。"
    else
      redirect_to @video, alert: result.error_message
    end
  end

  def video_params
    params.require(:video).permit(:title, :content, :analysis_status)
  end

  def index
    @videos = Video.order(
    Arel.sql("date DESC NULLS LAST"),
    created_at: :desc
  )
  end
  def show
    @video = Video.find(params[:id])
    @performances = @video.performances.includes(:performer)

    # 活動量データの計算
    @detected_ids = flash[:detected_ids] || @video.get_detected_ids
    @activity_data = @video.get_all_activities
    @overall_stats = @video.calculate_overall_stats
  end

  def player
    unless @video.analysis_status == "completed"
      redirect_to @video, alert: "動画の解析が完了していません"
      return
    end

    unless @video.detections.exists?
      redirect_to @video, alert: "検出データが存在しません"
      nil
    end
  end

  def frame_data
    frame_number = params[:frame_number].to_i

    detections = @video.detections
                      .where(frame_number: frame_number)
                      .map do |d|
      {
        frameNumber: d.frame_number,
        x1: d.x1.to_i,
        y1: d.y1.to_i,
        x2: d.x2.to_i,
        y2: d.y2.to_i,
        activityValue: d.activity&.round(2)
      }
    end

    render json: { detections: detections }
  end

  def all_frames_data
    # JOINで演者情報を取得
    detections_with_performers = @video.detections
                                       .left_joins(
                                         "LEFT JOIN performances ON
                                          detections.video_id = performances.video_id AND
                                          detections.person_id = performances.person_id"
                                       )
                                       .left_joins(
                                         "LEFT JOIN performers ON performances.performer_id = performers.id"
                                       )
                                       .select(
                                         "detections.*",
                                         "performers.name as performer_name"
                                       )
                                       .order(:frame_number)

    frames_data = detections_with_performers
                    .group_by(&:frame_number)
                    .transform_values do |detections|
      detections.map do |d|
        {
          frameNumber: d.frame_number,
          x1: d.x1.to_i,
          y1: d.y1.to_i,
          x2: d.x2.to_i,
          y2: d.y2.to_i,
          activityValue: d.activity&.round(2),
          personId: d.person_id,
          performerName: d.try(:performer_name)
        }
      end
    end

    # 演者ごとの色情報を生成
    performer_colors = {}
    colors = [ "#00ff00", "#ff0000", "#0000ff", "#ffff00", "#ff00ff", "#00ffff" ]
    @video.performances.includes(:performer).each_with_index do |performance, index|
      performer_colors[performance.performer.name] = colors[index % colors.length] if performance.performer
    end

    render json: {
      frames: frames_data,
      totalFrames: @video.detections.maximum(:frame_number) || 0,
      totalDetections: @video.detections.count,
      performerColors: performer_colors
    }
  end

  def edit
    @video = Video.find(params[:id])
  end

  def update
    if @video.update(video_params)
      redirect_to @video, notice: "更新しました"
    else
      render :edit
    end
  end

  def destroy
    @video.destroy
    redirect_to videos_path, notice: "動画を削除しました"
  end
  private

  def set_video
    @video = Video.find(params[:id])
  end
end

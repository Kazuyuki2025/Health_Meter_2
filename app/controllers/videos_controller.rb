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
      # 成功時
      if result.redirect_to_assign
        # 画像解析成功 → 演者紐付け画面へ
        flash[:detected_ids] = result.detected_ids
        flash[:notice] = result.notice_msg if result.notice_msg.present?
        redirect_to video_path(result.video)  # ← redirectに変更
      else
        # 画像解析失敗 → show画面へ
        flash[:notice] = result.notice_msg if result.notice_msg.present?
        redirect_to video_path(result.video)
      end
    else
      # 失敗時
      @video = result.video || Video.new
      @shooting_date = result.shooting_date
      @detected_ids = result.detected_ids
      @images = result.images
      @performers = Performer.all

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

      # 正規化モードと方法を取得（デフォルト値を設定）
      normalization_mode = params[:normalization_mode]&.to_sym || :auto
      normalization_method = params[:normalization_method]&.to_sym || :height

      DetectVideoJob.perform_later(
        @video.id,
        normalization_mode: normalization_mode,
        normalization_method: normalization_method
      )

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

    # 画像解析後の演者紐付け用
    @images = get_generated_images if @detected_ids&.any? && @video.analysis_status == "pending"
    @performers = Performer.all if @detected_ids&.any?
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
    @video = Video.find(params[:id])

    # Detectionデータが存在しない場合
    if @video.detections.empty?
      render json: {
        frames: {},
        totalFrames: 0,
        totalDetections: 0,
        performerColors: {},
        message: "解析データがありません"
      }
      return
    end

    # Detectionデータを取得
    detections = @video.detections.order(:frame_number)

    # person_idとperformanceのマッピングを作成
    person_to_performance = {}
    @video.performances.includes(:performer).each do |performance|
      if performance.person_id.present?
        person_to_performance[performance.person_id] = performance
      end
    end

    # フレームごとにグループ化
    frames_hash = {}
    detections.each do |detection|
      frame_num = detection.frame_number
      frames_hash[frame_num] ||= []

      # person_idからperformanceを取得
      performance = person_to_performance[detection.person_id]
      performer_name = performance&.performer&.name

      frames_hash[frame_num] << {
        x1: detection.x1,
        y1: detection.y1,
        x2: detection.x2,
        y2: detection.y2,
        activityValue: detection.activity,
        personId: detection.person_id,
        performerName: performer_name
      }
    end

    # Performerごとに色を割り当て
    performer_colors = {}
    color_palette = [ "#00ff00", "#ff0000", "#0000ff", "#ffff00", "#ff00ff", "#00ffff" ]

    @video.performances.includes(:performer).each_with_index do |performance, index|
      if performance.performer
        performer_colors[performance.performer.name] = color_palette[index % color_palette.length]
      end
    end

    render json: {
      frames: frames_hash,
      totalFrames: frames_hash.keys.max || 0,
      totalDetections: detections.count,
      performerColors: performer_colors
    }

  rescue => e
    Rails.logger.error "all_frames_data エラー: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: e.message,
      frames: {},
      totalFrames: 0,
      totalDetections: 0,
      performerColors: {}
    }, status: :internal_server_error
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

  def get_generated_images
    base_dir = Rails.root.join("public", "images", "detections", @video.id.to_s)
    return [] unless Dir.exist?(base_dir)

    Dir.glob(File.join(base_dir, "*.jpg")).map do |path|
      "/images/detections/#{@video.id}/#{File.basename(path)}"
    end.sort
  end
end

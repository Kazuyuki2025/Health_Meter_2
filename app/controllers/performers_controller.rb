class PerformersController < ApplicationController
  def new
    @performer = Performer.new
  end

  def create
    @performer = Performer.new(params.require(:performer).permit(:num, :name))

    if @performer.save
      redirect_to performers_path, notice: "が作成されました"
    else
      render :new, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "エラー発生: #{e.message}"
    flash.now[:alert] = "パフォーマーの作成中にエラーが発生しました"
    render :new, status: :unprocessable_entity
  end
  def show
    @performer = Performer.find(params[:id])
    @performances = @performer.performances.includes(:video, :activities).order(created_at: :desc)

    # 活動タイプの定義
    @activity_types = {
      0 => "伸びの運動",
      1 => "腕を振って脚を曲げ伸ばす運動",
      2 => "腕を回す運動",
      3 => "胸を反らす運動",
      4 => "体を横に曲げる運動",
      5 => "体を前後に曲げる運動",
      6 => "体をねじる運動",
      7 => "腕を上下に伸ばす運動",
      8 => "体を斜め下に曲げ胸を反らす運動",
      9 => "体を回す運動",
      10 => "両脚で跳ぶ運動",
      11 => "腕を振って脚を曲げ伸ばす運動",
      12 => "深呼吸"
    }

    # 各パフォーマンスの活動量データを計算
    @performance_data = @performances.map do |performance|
      activities = performance.activities.order(:category)
      next if activities.blank?

      {
        performance: performance,
        activities: activities,
        average: activities.map(&:value).sum.to_f / activities.size,
        total_segments: activities.size,
        video_title: performance.video.title,
        date: performance.date
      }
    end.compact

    # 全体統計
    if @performance_data.any?
      all_activities = @performance_data.flat_map { |data| data[:activities] }
      @overall_stats = {
        total_performances: @performance_data.size,
        total_segments: all_activities.size,
        overall_average: all_activities.map(&:value).sum.to_f / all_activities.size,
        highest_activity: all_activities.maximum(:value),
        lowest_activity: all_activities.minimum(:value)
      }
    else
      @overall_stats = {}
    end
  end

  def index
    @performers = Performer.all
  end

  def edit
    @performer = Performer.find(params[:id])
  end

  def update
    @performer = Performer.find(params[:id])
    if @performer.update(performer_params)
    redirect_to performers_path, notice: "動画情報を更新しました"
    else
    render :edit, status: :unprocessable_entity
    end
  end
  def destroy
    @performer = Performer.find(params[:id])
    @performer.destroy
    redirect_to performers_path, notice: "パフォーマーが削除されました"
  rescue => e
    Rails.logger.error "エラー発生: #{e.message}"
    flash.now[:alert] = "パフォーマーの削除中にエラーが発生しました"
    render :index, status: :unprocessable_entity
  end

  def healthy_ranking
    @ranking_data = Performer.with_activity_average
  end

  def performer_params
    params.require(:performer).permit(:num, :name)
  end
end

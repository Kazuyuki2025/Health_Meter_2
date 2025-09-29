require "open3"
require "json"

class PerformancesController < ApplicationController
  def new
    @performance = Performance.new
  end

  def create
    @performance = Performance.new(performance_params)

    if @performance.save
      redirect_to @performance, notice: "パフォーマンスが作成されました"
    else
      render :new, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "エラー発生: #{e.message}"
    flash.now[:alert] = "パフォーマンスの作成中にエラーが発生しました"
    render :new, status: :unprocessable_entity
  end
  def show
    @performance = Performance.find_by(id: params[:id])
    if @video
      @video = @video
    else
      @video = @performance.video
    end
    @average_activity = @performance.average_activity
    @activity_types = Activity.activity_types
    @activity_data = {
    activities: @performance.activities,  # ActiveRecordの配列
    average: @performance.average_activity,
    total: @performance.total_activity
  }
    @segment_activities = @performance.get_segment_activities
  end

  def edit
    @performance = Performance.find(params[:id])
    @performers = Performer.all
  end

  def update
    @performance = Performance.find(params[:id])
    if @performance.update(performance_params)
      redirect_to @performance, notice: "演者を紐付けました"
    else
      render :edit
    end
  end

  private

  def performance_params
    params.require(:performance).permit(:performer_id)
  end

  def set_performance
    if @video
      @performance = @video.performances.find(params[:id])
    else
      @performance = Performance.find(params[:id])
    end
  end
end

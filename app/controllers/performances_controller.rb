require "open3"
require "json"

class PerformancesController < ApplicationController
  def new
    @performance = Performance.new
  end

  def create
  end
  def show
    @performance = Performance.find_by(id: params[:id])
    if @video
      @video = @video
    else
      @video = @performance.video
    end
    @activity_data = {
      performer: @performance.performer,
      activities: @performance.activities.order(:category),
      average: @performance.average_activity,
      total_segments: @performance.activities.count
    }
    @segment_activities = @performance.get_segment_activities

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

  def index
    @performances = Performance.all
  end
  def set_performance
    if @video
      @performance = @video.performances.find(params[:id])
    else
      @performance = Performance.find(params[:id])
    end
  end
end

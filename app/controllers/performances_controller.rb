require "open3"
require "json"

class PerformancesController < ApplicationController
  def new
    @performance = Performance.new
  end

  def create
  end
  def show
    @performance = Performance.find(params[:id])
    @video = @performance.video
    @analysis_results = get_analysis_results
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

  def index
    @performances = Performance.all
  end
end

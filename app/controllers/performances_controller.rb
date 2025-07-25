class PerformancesController < ApplicationController
  def new
    @performance = Performance.new
  end

  def create
  end
  def show
    @performance = Performance.find(params[:id])
  end

  def index
    @performances = Performance.all
  end
end

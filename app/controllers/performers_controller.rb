class PerformersController < ApplicationController
  def new
    @performer = Performer.new
  end

  def show
    # 詳細表示ロジック
  end

  def index
  end
end

class PerformersController < ApplicationController
  def index
    @performers = Performer.all
  end

  def show
    # 詳細表示ロジック
  end

  def new
    # 新規作成フォーム表示
  end
end

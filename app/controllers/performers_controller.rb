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
end

def performer_params
  params.require(:performer).permit(:num, :name)
end

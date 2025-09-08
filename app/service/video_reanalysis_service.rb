require "open3"
require "shellwords"

class VideoReanalysisService
  include ActiveModel::Model
  include VideoAnalysisModule

  attr_accessor :video

  def initialize(video:)
    @video = video
  end

  def call
    return failure_result("動画が見つかりません") unless video

    perform_reanalysis
  end

  private

  attr_reader :video

  def perform_reanalysis
    # 既存のパフォーマンスデータを削除
    video.performances.destroy_all
    
    # ステータスをpendingに戻す
    video.update(analysis_status: :pending)

    # 顔検出の再実行
    if perform_analysis
      prepare_response_data
      success_result(@notice_msg)
    else
      failure_result("画像解析に失敗しました: #{@stderr}")
    end
  rescue => e
    Rails.logger.error "再解析エラー: #{e.message}"
    failure_result("再解析中にエラーが発生しました: #{e.message}")
  end

  def prepare_response_data
    @notice_msg = if @detected_ids&.any?
      "再解析が完了しました。#{@detected_ids.size} 人を検出しました。演者を紐付けてください。"
    else
      "再解析が完了しましたが、顔を検出できませんでした。"
    end

    @images = get_generated_images
  end

  def get_generated_images
    return [] unless video.thumbnail.attached?
    [ video.thumbnail_url ]
  end
end

class VideoUploadResult
  attr_reader :video, :shooting_date, :detected_ids, :error_message, :images, :notice_msg

  def initialize(success:, video: nil, shooting_date: nil, detected_ids: [], error_message: nil, images: [], notice_msg: nil)
    @success = success
    @video = video
    @shooting_date = shooting_date
    @detected_ids = detected_ids
    @error_message = error_message
    @images = images
    @notice_msg = notice_msg
  end

  def success?
    @success
  end

  # 便利メソッドを追加
  def failure?
    !@success
  end

  def has_detected_people?
    detected_ids && detected_ids.any?
  end

  def shooting_date_formatted
    return nil unless shooting_date
    
    begin
      Date.parse(shooting_date).strftime("%Y年%m月%d日")
    rescue
      shooting_date
    end
  end
end

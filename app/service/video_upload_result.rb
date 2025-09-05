class VideoUploadResult
  attr_reader :video, :detected_ids, :error_message, :images, :notice_msg
  def initialize(success:, video: nil, detected_ids: [], error_message: nil, images: [], notice_msg: nil)
    @success = success
    @video = video
    @detected_ids = detected_ids
    @error_message = error_message
    @images = images
    @notice_msg = notice_msg
  end
  def success?
    @success
  end
end

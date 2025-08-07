class DetectVideoJob < ApplicationJob
  queue_as :default

  def perform(video_id)
    video = Video.find(video_id)
    video_path = ActiveStorage::Blob.service.path_for(video.video_file.key)

    success = system("python3 app/controllers/python/detect_video.py #{Shellwords.escape(video_path)}")

    if success
      video.update!(status: "detected")
      VideoMailer.detect_complete(video).deliver_later
    else
      video.update!(status: "failed")
    end
    # Do something later
  end
end

class ExtractFirstFrameJob < ApplicationJob
  queue_as :default

  def perform(video_id)
    video = Video.find(video_id)
    video
    _path = ActiveStorage::Blob.service.send(:path_for, video.file.key)

    system("python3 app/controllers/python/extract_faces.py #{video.id} #{video_path}")
  end
end

namespace :video do
  desc "Export Detections of the last video to JSON in public"
  task export_detections: :environment do
    video = Video.find(260)
    puts "Exporting detections for video: #{video.title} (id=#{video.id})"

  data = {
    video_id: video.id,
    name: video.title,
      detections: video.detections.order(:frame_number).map do |d|
        {
          frame_number: d.frame_number,
          person_id: d.person_id,
          x1: d.x1,
          y1: d.y1,
          x2: d.x2,
          y2: d.y2,
          activity: d.activity
        }
      end
  }
    file_path = Rails.root.join("public", "detections_video_#{video.id}.json")
    File.open(file_path, "w") do |f|
      f.write(JSON.pretty_generate(data))
    end

    puts "Export completed: #{file_path}"
  end
end

namespace :calculation do
  desc "Calculate detections quotient for two videos"
  task detections_quotient: :environment do
    video1 = Video.find(251) # 1倍
    video2 = Video.find(248) # 2倍

    detections1 = video1.detections.order(:frame_number)
    detections2 = video2.detections.order(:frame_number)

    results = []
    outlier_count = 0

    detections1.each_with_index do |d1, i|
      d2 = detections2[i]
      next if d2.nil?

      quot = ->(a, b) { b.to_f.zero? ? nil : a.to_f / b.to_f }

      x1_q = quot.call(d2.x1, d1.x1)
      y1_q = quot.call(d2.y1, d1.y1)
      x2_q = quot.call(d2.x2, d1.x2)
      y2_q = quot.call(d2.y2, d1.y2)

      # 比が nil でなく、±0.1以上離れている箇所を数える
      [ x1_q, y1_q, x2_q, y2_q ].compact.each do |q|
        outlier_count += 1 if (q - 2.0).abs > 1.0
      end

      results << {
        frame: d1.frame_number,
        quotient: {
          x1: x1_q,
          y1: y1_q,
          x2: x2_q,
          y2: y2_q
        }
      }
    end

    data = {
      video1: { id: video1.id, name: video1.title },
      video2: { id: video2.id, name: video2.title },
      total_outlier_coordinates: outlier_count,
      results: results
    }

    file_path = Rails.root.join("public", "detections_quotient_video_#{video1.id}_#{video2.id}.json")
    File.write(file_path, JSON.pretty_generate(data))

    puts "Detections quotient exported to: #{file_path}"
    puts "Outliers(±0.1 over 2.0): #{outlier_count}"
  end
end

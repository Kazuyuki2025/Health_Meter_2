module VideosHelper
  def status_color(status)
    case status
    when "pending"
      "secondary"
    when "analyzing"
      "warning"
    when "completed"
      "success"
    when "failed"
      "danger"
    else
      "secondary"
    end
  end

  def status_icon(status)
    case status
    when "pending"
      "clock"
    when "analyzing"
      "spinner fa-spin"
    when "completed"
      "check-circle"
    when "failed"
      "exclamation-triangle"
    else
      "question-circle"
    end
  end

  def status_text(status)
    case status
    when "pending"
      "解析待ち"
    when "analyzing"
      "解析中"
    when "completed"
      "解析完了"
    when "failed"
      "解析失敗"
    else
      "不明"
    end
  end
end

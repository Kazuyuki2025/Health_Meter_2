module PerformersHelper
  def get_risk_level(low_z_count, total_categories)
    return :no_data if total_categories == 0

    risk_percentage = (low_z_count.to_f / total_categories * 100)

    case risk_percentage
    when 50..100
      :high
    when 20..49
      :medium
    when 1..19
      :low
    else
      :none
    end
  end

  def get_risk_label(risk_level)
    case risk_level
    when :high
      "高リスク"
    when :medium
      "中リスク"
    when :low
      "低リスク"
    when :none
      "正常"
    when :no_data
      "データ不足"
    end
  end

  def get_risk_badge_class(risk_level)
    case risk_level
    when :high
      "bg-danger"
    when :medium
      "bg-warning text-dark"
    when :low
      "bg-info"
    when :none
      "bg-success"
    when :no_data
      "bg-secondary"
    end
  end

  def get_risk_row_class(risk_level)
    case risk_level
    when :high
      "risk-high"
    when :medium
      "risk-medium"
    when :low
      "risk-low"
    else
      ""
    end
  end
end

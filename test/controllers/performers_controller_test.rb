require "test_helper"

class PerformersControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get performers_show_url
    assert_response :success
  end
end

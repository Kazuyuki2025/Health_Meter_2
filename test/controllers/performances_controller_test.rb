require "test_helper"

class PerformancesControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get performances_new_url
    assert_response :success
  end
end

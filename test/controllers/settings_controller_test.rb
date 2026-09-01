require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @password = "password" # matches test/fixtures/users.yml
  end

  test "unauthenticated users are sent to login" do
    get settings_path
    assert_redirected_to login_path
  end

  test "GET settings renders" do
    log_in_as(@user)
    get settings_path
    assert_response :success
  end

  test "PATCH settings updates the revenue threshold" do
    log_in_as(@user)
    patch settings_path, params: { revenue_threshold_millions: "1000" }

    assert_redirected_to settings_path
    assert_equal 1000, Setting.instance.revenue_threshold_millions
  end

  test "PATCH settings rejects zero, blank, and non-numeric values" do
    log_in_as(@user)

    [ "0", "", "abc" ].each do |bad|
      patch settings_path, params: { revenue_threshold_millions: bad }
      assert_redirected_to settings_path
      assert_equal 700, Setting.instance.revenue_threshold_millions,
                   "expected threshold to stay unchanged for #{bad.inspect}"
    end
  end

  private
    def log_in_as(user)
      post login_path, params: { email: user.email, password: @password }
    end
end

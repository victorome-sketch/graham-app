require "test_helper"

class SettingTest < ActiveSupport::TestCase
  test "instance returns the existing row" do
    assert_equal settings(:default), Setting.instance
  end

  test "instance creates a row with the default threshold when none exists" do
    Setting.delete_all
    assert_equal 700, Setting.instance.revenue_threshold_millions
  end

  test "rejects a missing, zero, or negative threshold" do
    setting = Setting.instance

    assert_not setting.update(revenue_threshold_millions: nil)
    assert_not setting.update(revenue_threshold_millions: 0)
    assert_not setting.update(revenue_threshold_millions: -5)
    assert setting.update(revenue_threshold_millions: 850)
  end
end

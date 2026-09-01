class SettingsController < ApplicationController
  def show
    render inertia: "Settings", props: {
      settings: { revenue_threshold_millions: Setting.instance.revenue_threshold_millions.to_f }
    }
  end

  def update
    setting = Setting.instance

    if setting.update(params.permit(:revenue_threshold_millions))
      redirect_to settings_path, notice: "Settings updated."
    else
      redirect_to settings_path,
                  inertia: { errors: setting.errors.to_hash(true).transform_values(&:first) }
    end
  end
end

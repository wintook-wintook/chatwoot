class SwaggerController < ApplicationController
  def respond
    swagger_enabled = Rails.env.development? || Rails.env.test? ||
                      ActiveModel::Type::Boolean.new.cast(ENV.fetch('SWAGGER_ENABLED', false))

    if swagger_enabled
      render inline: Rails.root.join('swagger', derived_path).read
    else
      head :not_found
    end
  end

  private

  def derived_path
    params[:path] ||= 'index.html'
    path = Rack::Utils.clean_path_info(params[:path])
    path << ".#{Rack::Utils.clean_path_info(params[:format])}" unless path.ends_with?(params[:format].to_s)
    path
  end
end

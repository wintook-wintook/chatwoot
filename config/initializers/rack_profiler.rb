# frozen_string_literal: true

# Rack Mini Profiler — el contador de milisegundos de la esquina superior izquierda.
# Solo en desarrollo y solo si se pide con ENABLE_MINI_PROFILER=true en el .env: en el
# servidor de pruebas que se abre desde el teléfono (Dali) estorbaba.
if Rails.env.development? && ActiveModel::Type::Boolean.new.cast(ENV.fetch('ENABLE_MINI_PROFILER', false))
  require 'rack-mini-profiler'

  # initialization is skipped so trigger it
  Rack::MiniProfilerRails.initialize!(Rails.application)
end

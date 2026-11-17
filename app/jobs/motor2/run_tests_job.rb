# frozen_string_literal: true

# Motor 2.0 — vuelve a correr las pruebas guardadas de un agente (al corregirse un reporte).
class Motor2::RunTestsJob < ApplicationJob
  queue_as :low

  def perform(template_id)
    template = TrackingTemplate.find_by(id: template_id, engine: Motor2::ENGINE)
    return unless template

    runner = Motor2::TestRunner.new(template)
    Motor2Test.where(tracking_template_id: template.id).find_each { |test| runner.run(test) }
  end
end

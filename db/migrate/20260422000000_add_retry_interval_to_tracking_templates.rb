# proyecto@automatizacion_tracking: agrega intervalo entre intentos a la plantilla
# para que la automatización pueda programar el primer intento con el mismo intervalo
class AddRetryIntervalToTrackingTemplates < ActiveRecord::Migration[7.0]
  def change
    add_column :tracking_templates, :retry_interval_value, :integer, default: 1
    add_column :tracking_templates, :retry_interval_unit, :string, default: 'days'
  end
end

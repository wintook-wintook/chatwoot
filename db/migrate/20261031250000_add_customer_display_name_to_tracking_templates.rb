# Agentes IA — el nombre con el que el cliente ve al agente en la conversación (p. ej.
# «Sofía»). En WhatsApp va al inicio de sus mensajes; vacío, sus mensajes salen sin nombre
# (antes salían con el del primer usuario de la cuenta).
class AddCustomerDisplayNameToTrackingTemplates < ActiveRecord::Migration[7.0]
  def change
    add_column :tracking_templates, :customer_display_name, :string
  end
end

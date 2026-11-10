# Seguimiento IA — plantilla de WhatsApp fijada por quien delega para reabrir la ventana de
# 24 h. Vacía = el agente elige entre las aprobadas de la bandeja.
class AddTemplateToAiFollowUps < ActiveRecord::Migration[7.0]
  def change
    add_column :ai_follow_ups, :template_name, :string
    add_column :ai_follow_ups, :template_language, :string
  end
end

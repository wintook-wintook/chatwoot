# prospeccion V1 — firma del Agente IA para correo. En correo reemplaza las marcas
# « #IA» (toque) y «-TB» (respuesta), que delatan el envío automático.
class AddEmailSignatureToTrackingTemplates < ActiveRecord::Migration[7.0]
  def change
    add_column :tracking_templates, :email_signature, :text
  end
end

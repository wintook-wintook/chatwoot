# frozen_string_literal: true

# @waba_templates — plantillas de WhatsApp gestionadas desde Chatwoot (crear/submit/editar
# /borrar contra Meta). Tabla propia; NO reutiliza el JSONB channel_whatsapp.message_templates.
class CreateWhatsappTemplates < ActiveRecord::Migration[7.0]
  def change
    create_table :whatsapp_templates do |t|
      t.bigint :account_id,          null: false
      t.bigint :channel_whatsapp_id, null: false

      t.string :name,     null: false
      t.string :category                       # MARKETING / UTILITY / AUTHENTICATION
      t.string :language, null: false

      # header: text | image | video | document (o nulo)
      t.string :header_type
      t.text   :header_content                 # texto de cabecera
      t.string :header_media_url               # URL origen para el resumable upload
      t.string :header_handle                  # handle 'h:...' devuelto por Meta

      t.text   :body_text
      t.string :footer_text

      t.jsonb  :buttons,       null: false, default: []
      t.jsonb  :sample_values, null: false, default: {} # { body: [...], header: [...] }

      # status guarda el enum CRUDO de Meta (DRAFT/PENDING/APPROVED/REJECTED/PAUSED/
      # DISABLED/IN_APPEAL/PENDING_DELETION) para casar 1:1 con el webhook.
      t.string   :status, null: false, default: 'DRAFT'
      t.string   :meta_template_id
      t.string   :rejection_reason
      t.string   :quality_score                # GREEN / YELLOW / RED
      t.text     :submission_error
      t.datetime :last_submitted_at

      t.timestamps
    end

    add_index :whatsapp_templates, [:channel_whatsapp_id, :name, :language], unique: true,
                                                                             name: 'index_whatsapp_templates_on_channel_name_language'
    add_index :whatsapp_templates, :meta_template_id
    add_index :whatsapp_templates, :account_id
  end
end

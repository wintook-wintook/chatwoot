# frozen_string_literal: true

# proyecto@ai_agent_assistant — F4: versionado en sitio del Agente IA.
#
# Hoy «mejorar un agente» significa duplicarlo: la cuenta 778 tiene seis copias
# vivas del mismo caso de uso, con un error que sobrevivió a tres de ellas y sin
# forma de comparar ni volver atrás. Esta tabla guarda un snapshot por guardado,
# con autor y nota, para poder iterar sobre el MISMO agente.
#
# `archived_at` es la otra mitad: las copias que ya existen se archivan en vez de
# borrarse (conservan su historial y sus seguimientos), y dejan de aparecer en las
# listas de asignación.
class CreateTrackingTemplateVersions < ActiveRecord::Migration[7.0]
  def change
    create_table :tracking_template_versions do |t|
      t.bigint   :account_id,           null: false
      t.bigint   :tracking_template_id, null: false
      t.bigint   :user_id
      t.integer  :version,  null: false, default: 1
      t.string   :source,   null: false, default: 'manual'
      t.string   :note
      t.jsonb    :snapshot, null: false, default: {}
      t.datetime :created_at, null: false
    end

    add_index :tracking_template_versions, %i[tracking_template_id version],
              unique: true, name: 'index_tracking_template_versions_on_template_and_version'
    add_index :tracking_template_versions, :account_id

    add_foreign_key :tracking_template_versions, :accounts, column: :account_id
    add_foreign_key :tracking_template_versions, :tracking_templates,
                    column: :tracking_template_id, on_delete: :cascade
    add_foreign_key :tracking_template_versions, :users, column: :user_id, on_delete: :nullify

    # NULL = activo. Un agente archivado conserva todo; solo sale de las listas.
    add_column :tracking_templates, :archived_at, :datetime
    add_index  :tracking_templates, :archived_at
  end
end

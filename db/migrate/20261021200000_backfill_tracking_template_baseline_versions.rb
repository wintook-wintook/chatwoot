# frozen_string_literal: true

# feat/agentes_ia_unificado — cada Agente IA que ya existía arranca con su v1
# («Estado inicial», source `baseline`) con cómo está hoy. Sin esto la sección
# Versiones del espacio del agente saldría vacía hasta el primer cambio, y el primer
# diff no tendría contra qué compararse. Los que ya tienen versiones no se tocan.
#
# Modelos propios de la migración (no TrackingTemplate/TrackingTemplateVersion): esos pueden cambiar o
# tener callbacks; estos solo leen y escriben las columnas, con sus tipos.
class BackfillTrackingTemplateBaselineVersions < ActiveRecord::Migration[7.0]
  class Template < ApplicationRecord
    self.table_name = 'tracking_templates'
  end

  class Version < ApplicationRecord
    self.table_name = 'tracking_template_versions'
  end

  FIELDS = %w[
    name objective ai_context complementary_prompt inbox_id
    tags whatsapp_templates keyword_actions
    retry_interval_value retry_interval_unit
    calendar_integration_ids booking_calendar_ids
    slots_presentation calendar_event_duration timezone kbase_hook_id
  ].freeze

  def up
    con_versiones = Version.distinct.pluck(:tracking_template_id)
    Template.where.not(id: con_versiones).find_each do |template|
      Version.create!(account_id: template.account_id, tracking_template_id: template.id,
                      version: 1, source: 'baseline', snapshot: template.attributes.slice(*FIELDS),
                      created_at: Time.current)
    end
  end

  def down
    con_mas = Version.where('version > 1').distinct.pluck(:tracking_template_id)
    Version.where(source: 'baseline', version: 1).where.not(tracking_template_id: con_mas).delete_all
  end
end

# @knowledge_sources
# Renombra las fuentes auto-generadas a la terminología nativa de Chatwoot,
# localizada según el idioma de la cuenta:
#   - article         'Base de Conocimiento'  → Centro de Ayuda / Help Center
#   - canned_response 'Respuestas Predefinidas'→ Respuestas predefinidas / Canned Responses
# Solo toca las que conservan el nombre hardcodeado viejo (no pisa nombres personalizados).
class RenameKnowledgeSourceNamesI18n < ActiveRecord::Migration[6.1]
  OLD_NAMES = {
    'article'         => 'Base de Conocimiento',
    'canned_response' => 'Respuestas Predefinidas'
  }.freeze

  def up
    OLD_NAMES.each do |source_type, old_name|
      KnowledgeSource.where(source_type: source_type, name: old_name).find_each do |source|
        locale    = source.account&.locale.presence || I18n.default_locale
        new_name  = I18n.t("knowledge_sources.names.#{source_type}", locale: locale, default: old_name)
        source.update_columns(name: new_name) # rubocop:disable Rails/SkipsModelValidations
      end
    end
  end

  def down
    OLD_NAMES.each do |source_type, old_name|
      KnowledgeSource.where(source_type: source_type).find_each do |source|
        locale   = source.account&.locale.presence || I18n.default_locale
        cur_name = I18n.t("knowledge_sources.names.#{source_type}", locale: locale, default: nil)
        source.update_columns(name: old_name) if cur_name.present? && source.name == cur_name # rubocop:disable Rails/SkipsModelValidations
      end
    end
  end
end

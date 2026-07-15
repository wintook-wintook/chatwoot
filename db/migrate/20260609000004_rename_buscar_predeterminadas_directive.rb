# @knowledge_sources / @contact_tracking
# Renombra la directiva @buscar_predeterminadas → @buscar_predefinidas en el
# complementary_prompt de trackings y plantillas existentes, para que los bots en
# vivo (y los nuevos generados desde plantillas) sigan disparando la búsqueda en
# Respuestas predefinidas tras el rename en el código.
class RenameBuscarPredeterminadasDirective < ActiveRecord::Migration[6.1]
  TABLES = %w[contact_trackings tracking_templates].freeze

  def up
    TABLES.each do |table|
      execute(<<~SQL.squish)
        UPDATE #{table}
           SET complementary_prompt = REPLACE(complementary_prompt, '@buscar_predeterminadas', '@buscar_predefinidas')
         WHERE complementary_prompt LIKE '%@buscar_predeterminadas%'
      SQL
    end
  end

  def down
    TABLES.each do |table|
      execute(<<~SQL.squish)
        UPDATE #{table}
           SET complementary_prompt = REPLACE(complementary_prompt, '@buscar_predefinidas', '@buscar_predeterminadas')
         WHERE complementary_prompt LIKE '%@buscar_predefinidas%'
      SQL
    end
  end
end

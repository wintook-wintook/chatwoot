# frozen_string_literal: true

# proyecto@asistente_agentes_ia — llena training_structure en los agentes anteriores a
# la columna y verifica el invariante: si armar la estructura no devuelve el texto
# idéntico, el agente se deja SIN estructura (se abre en vista Texto) y se reporta.
namespace :agentes_ia do
  namespace :training_structure do
    desc 'Separa el Entrenamiento de cada Agente IA en bloques y verifica el ida y vuelta'
    task backfill: :environment do
      ok = 0
      fallas = []
      TrackingTemplate.find_each do |template|
        texto = template.complementary_prompt.to_s
        estructura = ContactTrackings::TrainingStructure.parse(texto)
        if ContactTrackings::TrainingStructure.compose(estructura) == texto
          # Sin validaciones ni callbacks a propósito: se llena una columna derivada, y un
          # agente viejo que hoy no pasa alguna validación no debe quedar sin estructura.
          template.update_columns(training_structure: estructura) # rubocop:disable Rails/SkipsModelValidations
          ok += 1
        else
          fallas << template.id
        end
      end
      puts "Agentes con estructura: #{ok}. Sin estructura (no rearman idéntico): #{fallas.size} #{fallas.inspect if fallas.any?}"
    end
  end
end

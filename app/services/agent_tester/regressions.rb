# frozen_string_literal: true

# Probador de agentes — cómo salió cada prueba la última vez que se corrió con el mismo agente,
# antes de esta corrida. Con eso la bitácora marca las que EMPEORARON (pasaba y ya no: un arreglo
# rompió otra cosa) y las que MEJORARON.
#
# Solo se comparan corridas con la misma búsqueda (seleccion): comparar la nueva contra la de
# siempre es «Comparar búsquedas», no una regresión.
#
#   AgentTester::Regressions.before(run) → { case_id => true | false }
module AgentTester::Regressions
  LOOKBACK = 30

  module_function

  def before(run)
    previas = AgentTestRun.where(tracking_template_id: run.tracking_template_id, seleccion: run.seleccion)
                          .where('created_at < ?', run.created_at).where.not(id: run.id)
                          .order(created_at: :desc).limit(LOOKBACK)
    previas.each_with_object({}) do |previa, acc|
      Array(previa.results).each do |r|
        id = r['case_id'].to_i
        acc[id] = r['ok'] == true unless id.zero? || acc.key?(id)
      end
    end
  end
end

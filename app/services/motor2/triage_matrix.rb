# frozen_string_literal: true

# «Atención a clientes» › «Probar la matriz» (Plan-Motor-Agentes §11.15.3, paso 9): corre cada ejemplo
# de «sí» y «no» de las áreas por el clasificador (Motor2::Triage), como si fuera el primer mensaje, y
# dice si cayó donde debía: un «sí» de Soporte debe dar Soporte; un «no» de Soporte, cualquier otra.
#
#   Motor2::TriageMatrix.new(account, areas).call
#   → [{ example:, area:, kind: 'yes'|'no', got:, ok: }]
# Máximo MAX ejemplos por corrida; varios a la vez para que no tarde.
class Motor2::TriageMatrix
  MAX = 40
  THREADS = 6

  def initialize(account, areas)
    @account = account
    @areas = areas
  end

  def call
    rows = cases.first(MAX)
    rows.each_slice(THREADS).flat_map do |slice|
      slice.map { |row| Thread.new { check(row) } }.map(&:value)
    end
  end

  private

  def cases
    @areas.flat_map do |area|
      Array(area['examples_yes']).map { |e| { example: e, area: area['key'], kind: 'yes' } } +
        Array(area['examples_no']).map { |e| { example: e, area: area['key'], kind: 'no' } }
    end
  end

  def check(row)
    result = Rails.application.executor.wrap do
      Motor2::Triage.new(account: @account).call(areas: @areas, history: [{ role: 'user', content: row[:example] }])
    end
    got = result&.dig('atender', 'area')
    ok = got && (row[:kind] == 'yes' ? got == row[:area] : got != row[:area])
    row.merge(got: got, ok: ok ? true : false)
  end
end

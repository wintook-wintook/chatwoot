# frozen_string_literal: true

# ================================================================================
# @tickets_cases 2B
# ================================================================================
# Servicio: Cases::PriorityMatrix
# Deriva la prioridad de un ticket a partir de Impacto × Urgencia (estándar ITIL).
#
#                       U R G E N C I A
#              │  Baja   │  Media  │  Alta
#   ───────────┼─────────┼─────────┼──────────
#   I  Alto    │ P2 Alta │ P2 Alta │ P1 CRÍTICA
#   M  Medio   │ P4 Baja │ P3 Media│ P2 Alta
#   P  Bajo    │ P4 Baja │ P4 Baja │ P3 Media
#
#   P1 Crítica = urgent · P2 Alta = high · P3 Media = medium · P4 Baja = low
# ================================================================================

class Cases::PriorityMatrix
  MATRIX = {
    'high'   => { 'low' => 'high',   'medium' => 'high',   'high' => 'urgent' },
    'medium' => { 'low' => 'low',    'medium' => 'medium', 'high' => 'high'   },
    'low'    => { 'low' => 'low',    'medium' => 'low',    'high' => 'medium' }
  }.freeze

  # Retorna la prioridad derivada (string) o nil si falta impacto o urgencia.
  def self.derive(impact, urgency)
    return nil if impact.blank? || urgency.blank?

    MATRIX.dig(impact.to_s, urgency.to_s)
  end
end

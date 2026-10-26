# frozen_string_literal: true

# proyecto@asistente_agentes_ia — lo que devuelve un turno de entrevista.
# Vive aparte para que InterviewService y TurnOutcome lo compartan sin depender uno
# del otro. Ver InterviewService y el controlador para qué es cada campo.
ContactTrackings::Assistant::InterviewResult = Struct.new(
  :reply, :draft, :validation, :repairs, :route_mismatches, :proposal, :options,
  :changes, :rejected_draft, :rejected_validation, :manual_conflict, :building, :error,
  keyword_init: true
) do
  def success? = error.blank?
end

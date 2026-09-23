# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — EN QUÉ ESTÁ EL ASISTENTE (fase D de PROMPT STUDIO)
# ================================================================================
# Un turno puede ser una sola llamada de 3 s o, editando un Entrenamiento grande,
# varias de 40–58 s: redactar, comprobar, corregir, probar el ruteo. Con un único
# "pensando…" durante dos minutos no se sabe si se colgó.
#
# La entrevista avisa cada etapa REAL por acá y la pantalla la consulta mientras
# espera. No son etapas simuladas por tiempo: una etapa inventada es justamente lo
# que el documento de requisitos pide no mostrar.
#
# Redis y no la base: es un dato que dura lo que dura el turno y se escribe varias
# veces por segundo en el peor caso. La clave lleva cuenta y usuario: el id del
# turno lo genera el cliente, y nadie más puede leer el progreso de otro.
# ================================================================================

class ContactTrackings::Assistant::TurnProgress
  TTL = 10.minutes
  TURN_ID_RE = /\A[A-Za-z0-9_-]{8,64}\z/
  # reading_brief / merging_brief: leer y juntar un encargo (AgentBriefDigestJob).
  STAGES = %w[writing mode_check edit_repair checking repairing routing routing_repair testing optimizing
              reading_brief merging_brief].freeze

  def self.read(account, user, turn_id)
    return nil unless turn_id.to_s.match?(TURN_ID_RE)

    raw = Redis::Alfred.get(key(account, user, turn_id))
    raw.present? ? JSON.parse(raw) : nil
  rescue JSON::ParserError
    nil
  end

  def self.key(account, user, turn_id)
    "assistant_progress:#{account.id}:#{user.id}:#{turn_id}"
  end

  # El resultado final de un turno que corre en Sidekiq (ver OptimizeJob): la request
  # HTTP no puede esperarlo (rack-timeout corta a los 15 s) y la pantalla lo consulta.
  def self.result_key(account, user, turn_id)
    "assistant_result:#{account.id}:#{user.id}:#{turn_id}"
  end

  def self.store_result(account, user, turn_id, result)
    return unless turn_id.to_s.match?(TURN_ID_RE)

    Redis::Alfred.setex(result_key(account, user, turn_id), result.to_json, TTL)
  end

  def self.read_result(account, user, turn_id)
    return nil unless turn_id.to_s.match?(TURN_ID_RE)

    raw = Redis::Alfred.get(result_key(account, user, turn_id))
    raw.present? ? JSON.parse(raw) : nil
  rescue JSON::ParserError
    nil
  end

  def initialize(account, user, turn_id)
    @key = turn_id.to_s.match?(TURN_ID_RE) ? self.class.key(account, user, turn_id) : nil
  end

  # Nunca rompe el turno: si Redis no está, la pantalla muestra la espera genérica.
  def update(stage, **info)
    return if @key.nil? || STAGES.exclude?(stage.to_s)

    Redis::Alfred.setex(@key, info.merge(stage: stage.to_s).to_json, TTL)
  rescue StandardError => e
    Rails.logger.warn "[Asistente] no se pudo registrar el progreso: #{e.message}"
  end
end

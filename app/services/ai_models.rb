# frozen_string_literal: true

# Los modelos de OpenAI de la plataforma, por grupo de trabajo. Se definen AQUÍ, en el código, igual
# para todas las cuentas: para cambiar uno se cambia esta constante y se despliega (ya no se elige
# por cuenta). En Ajustes › Cuenta se enseña la tabla (solo informativa).
#
# Lo que decide el grupo es qué tan caro sale un error y cuántas veces se usa:
#   dali / dali_analysis  el asistente de la plataforma (habla con el equipo; un error se corrige al momento)
#   agents                agentes 2.0, agentes listos y Seguimiento IA (habla con clientes: sigue reglas y
#                         secuencias; gpt-4o-mini se saltaba preguntas, gpt-4.1-mini no — medido el 19/11)
#   review                entrenador, juez y pruebas del probador, «Pasar a 2.0» (pocas llamadas, debe razonar)
# Los internos que ya se midieron tienen su modelo en su propio servicio (la tabla los enseña):
#   KnowledgeBase::Selector::MODEL (escoger respuestas predefinidas) y SheetQueryService (hojas en modo
#   «Datos», gpt-4o-mini escrito en #openai_chat: si se cambia allá, cambiar SHEETS aquí).
# Los agentes 1.0 usan el de su bandeja (ContactTrackings::EngineConfig).
module AiModels
  DALI = 'gpt-4o-mini'
  DALI_ANALYSIS = 'gpt-4o-mini'
  AGENTS = 'gpt-4.1-mini'
  REVIEW = 'gpt-4.1-mini'
  SHEETS = 'gpt-4o-mini' # el que usa SheetQueryService (solo para la tabla)

  module_function

  # La tabla para Ajustes: { key, model } por grupo (los textos los pone la pantalla).
  def table
    [
      { key: 'dali', model: DALI },
      { key: 'dali_analysis', model: DALI_ANALYSIS },
      { key: 'agents', model: AGENTS },
      { key: 'review', model: REVIEW },
      { key: 'canned_selector', model: KnowledgeBase::Selector::MODEL },
      { key: 'sheets', model: SHEETS },
      { key: 'agents_v1', model: nil },
      { key: 'other', model: ENV.fetch('OPENAI_GPT_MODEL', Cases::Ai::BaseService::DEFAULT_MODEL) }
    ]
  end
end

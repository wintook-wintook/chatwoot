# frozen_string_literal: true

# Asistente (Dali) — «Arma tu cuenta con Dali» (formato de OpenAI). Lo que hace vive en
# Assistant::SetupTools y Assistant::SetupRunner.
module Assistant::SetupToolDefinitions
  D = Assistant::ToolDefinitions

  STAGES = { type: 'array', items: { type: 'string' },
             description: 'Etapas del avance, en orden, con las palabras del negocio (2 a 6). Sin las de resultado ' \
                          '(Ganada, Perdida, Cerrado, Cancelada) ni «Pospuesta»/«En espera»: esas se agregan solas.' }.freeze
  REASONS = { type: 'array', items: { type: 'string' } }.freeze

  ALL = [
    D.fn('propose_account_setup', 'Solo administradores. Propone crear los tipos de caso de su negocio con sus etapas, y ' \
                                  'motivos de venta ganada/perdida. Solo agrega: no cambia los tipos que ya hay. Requiere confirmación.',
         { case_types: { type: 'array', description: '1 a 4 tipos de caso',
                         items: { type: 'object', properties: {
                           name: D.str('Nombre corto, p. ej. «Venta de equipo», «Servicio técnico»'),
                           case_class: { type: 'string', enum: %w[commercial support work_order project],
                                         description: 'commercial = ventas (embudo con Ganada/Perdida); support = servicio o ' \
                                                      'soporte; work_order = trabajo en campo; project = proyecto' },
                           stages: STAGES
                         }, required: %w[name case_class stages] } },
           won_reasons: REASONS.merge(description: 'Por qué se gana una venta en ese negocio (3 a 5)'),
           lost_reasons: REASONS.merge(description: 'Por qué se pierde una venta en ese negocio (3 a 5)'),
           retire_defaults: { type: 'boolean', description: 'Retirar los tipos de fábrica que no tienen casos (true si empieza de cero)' } },
         %w[case_types])
  ].freeze
end

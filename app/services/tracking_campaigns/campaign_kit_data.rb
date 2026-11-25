# frozen_string_literal: true

# Campaña con IA — lo de fábrica de cada tipo (TrackingCampaigns::CampaignKit explica cada pieza).
module TrackingCampaigns::CampaignKitData
  FACT_LABELS = {
    'when' => 'Cuándo', 'place' => 'Dónde o cómo (lugar, en línea)', 'cost' => 'Costo', 'audience' => 'Para quién es',
    'not_for' => 'Para quién NO es', 'agenda' => 'Qué se verá', 'what_is' => 'Qué es', 'price' => 'Precio',
    'valid_until' => 'Vigencia', 'conditions' => 'Condiciones', 'delivery' => 'Entrega o existencias',
    'news' => 'Qué hay de nuevo', 'incentive' => 'Incentivo para volver', 'what_due' => 'Qué vence',
    'how' => 'Cómo hacerlo (pasos)', 'where_pay' => 'Dónde pagar o renovar', 'if_not' => 'Qué pasa si no lo hace',
    'purpose' => 'Para qué es la encuesta', 'duration' => 'Cuánto tarda', 'use' => 'Qué se hace con las respuestas',
    'more' => 'Más datos'
  }.freeze

  KIT = {
    'invite' => {
      goals: %w[confirm external], keyword: 'REGISTRADO',
      facts: %w[when place cost audience not_for agenda more],
      replies: {
        'achieved' => '¡Muchas gracias por confirmar! 😊 Nos dará gusto contar contigo. ¡Te esperamos!',
        'not_now' => 'Entiendo, no hay problema 😊 ¿Te parece bien que te invitemos a un próximo evento?',
        'future_yes' => '¡Perfecto! Te avisamos del próximo evento. 😊',
        'opt_out' => 'Entendido, respetaremos tu decisión. Gracias por avisarnos.'
      },
      labels: { 'future_yes' => 'volver-a-invitar', 'opt_out' => 'no-invitar' }
    },
    'offer' => {
      goals: %w[relay appointment external], keyword: 'LISTO',
      facts: %w[what_is price valid_until conditions audience delivery more],
      replies: {
        'achieved' => '¡Muchas gracias! 😊 Cualquier duda aquí estoy.',
        'not_now' => 'Entiendo, no hay problema 😊 ¿Te aviso cuando tengamos otra promoción?',
        'future_yes' => '¡Va! Te aviso de la próxima. 😊',
        'opt_out' => 'Entendido, ya no te enviaremos promociones. Gracias por avisarnos.'
      },
      labels: { 'future_yes' => 'avisar-promociones', 'opt_out' => 'no-ofrecer' }
    },
    'reactivate' => {
      goals: %w[relay appointment external], keyword: 'LISTO',
      facts: %w[news incentive valid_until conditions more],
      replies: {
        'achieved' => '¡Qué gusto tenerte de vuelta! 😊',
        'not_now' => 'Entiendo, gracias por contarme 😊 ¿Te parece si te escribimos más adelante?',
        'future_yes' => '¡Va! Te escribimos más adelante. 😊',
        'opt_out' => 'Entendido, no volveremos a escribirte por esto. Gracias por avisarnos.'
      },
      labels: { 'future_yes' => 'volver-a-contactar', 'opt_out' => 'no-reactivar' }
    },
    'renew' => {
      goals: %w[done relay external], keyword: 'PAGADO',
      facts: %w[what_due how where_pay if_not more],
      replies: {
        'achieved' => '¡Gracias por avisarnos! 😊 Queda registrado.',
        'not_now' => '', 'future_yes' => '',
        'opt_out' => 'Entendido. Si necesitas ayuda más adelante, aquí estoy.'
      },
      labels: {}
    },
    'survey' => {
      goals: %w[answers], keyword: '',
      facts: %w[purpose duration use more],
      replies: { 'achieved' => '¡Gracias por tu tiempo! 😊', 'not_now' => '', 'future_yes' => '',
                 'opt_out' => 'Entendido, gracias de todos modos. 😊' },
      labels: { 'opt_out' => 'no-encuestas' }
    }
  }.freeze
end

# frozen_string_literal: true

# Función «Cobranza» (agente listo): le escribe a los clientes con saldo de la cartera (receivable_* — Receivables::
# Snapshot, venga del Excel o del sistema administrativo) y atiende lo que contestan (Motor2::Skills::Collections).
# Lo que contestó en su asistente (motor2['answers']):
#
#   payment_info       DATOS PARA PAGAR (banco, cuenta, CLABE, referencia…), tal cual se le dan al cliente
#   user_id / team_id  el cobrador por omisión (si la cartera no trae cobrador para ese cliente)
#   outreach_on        cobrar solo (Receivables::OutreachJob) · send_hour (hora del envío) · weekdays_only
#   remind_before_days aviso antes de vencer (0 = no) · every_days cada cuántos días a quien sigue debiendo
#   max_per_day        tope de clientes por día · min_balance (no se cobra menos de esto)
#   templates          { preventive, due, overdue_30, overdue_60, overdue_plus } plantilla de WhatsApp por etapa
#   tone · business_* · voice (Functions::Extras)
class Motor2::Functions::Collections
  include Motor2::Functions::Extras

  KEY = 'collections'
  TEXTS = %w[tone payment_info business_what business_who business_coverage business_why business_practical].freeze
  TONES = Motor2::Functions::Prospects::TONES
  STAGE_TEXT = {
    'preventive' => 'RECORDATORIO amable: tiene facturas por vencer (todavía no vence nada).',
    'due' => 'RECIÉN VENCIDO (1 a 15 días): recordatorio cordial, quizá se le pasó.',
    'overdue_30' => 'VENCIDO de 16 a 30 días: firme y amable; busca una fecha de pago.',
    'overdue_60' => 'VENCIDO de 31 a 60 días: serio y respetuoso; consigue una fecha de pago o pásalo al cobrador.',
    'overdue_plus' => 'VENCIDO más de 60 días: serio y respetuoso; si no hay fecha de pago, pásalo al cobrador.'
  }.freeze

  def self.sanitize(raw)
    raw = Motor2::Sanitizer.plain(raw)
    out = TEXTS.index_with { |k| raw[k].to_s.strip.first(1500) }
    out.merge(numbers(raw), 'templates' => templates(raw['templates']),
                            'outreach_on' => ActiveModel::Type::Boolean.new.cast(raw['outreach_on']) || false,
                            'weekdays_only' => raw.key?('weekdays_only') ? ActiveModel::Type::Boolean.new.cast(raw['weekdays_only']) : true)
       .merge(Motor2::Functions::Extras.sanitize(raw)).compact
  end

  NUMBERS = { 'send_hour' => [10, 7..20], 'remind_before_days' => [3, 0..15], 'every_days' => [7, 1..30],
              'max_per_day' => [100, 1..2000] }.freeze

  def self.numbers(raw)
    NUMBERS.to_h { |k, (default, range)| [k, (raw[k].presence || default).to_i.clamp(range.min, range.max)] }
           .merge('user_id' => raw['user_id'].to_s.presence&.to_i, 'team_id' => raw['team_id'].to_s.presence&.to_i,
                  'min_balance' => raw['min_balance'].to_s.presence&.to_f || 1.0)
  end

  def self.templates(raw)
    Receivables::Summary::STAGES.index_with { |s| Motor2::Sanitizer.plain(raw)[s].to_s.strip.first(200) }.compact_blank
  end

  attr_reader :config

  delegate :answers, to: :config

  def initialize(config)
    @config = config
  end

  def key = KEY

  def answer(name) = answers[name.to_s]

  def tone = (TONES[answer(:tone)] || TONES['cercano']).first

  def payment_info = answer(:payment_info).to_s.strip

  def handoff_target = { user_id: answer(:user_id), team_id: answer(:team_id) }

  def template_for(stage) = answer(:templates).to_h[stage.to_s].presence

  def setting(name) = answer(name)

  def skills
    { 'collections' => { 'on' => true },
      'handoff' => { 'on' => true, 'when' => 'pide el estado de cuenta formal, una factura en PDF, un descuento o convenio, ' \
                                             'hablar con alguien, se molesta o dice que no va a pagar' }
        .merge(handoff_target.transform_keys(&:to_s)) }
  end

  def outcomes(tracking, conversation) = Motor2::Functions::CollectionsOutcomes.new(tracking, conversation, self)

  def prompt(conversation = nil)
    [Motor2::Functions.puesto(KEY), debt_block(conversation), payment_block, business_block].map { |b| b.to_s.strip }
                                                                                            .compact_blank.join("\n\n")
  end

  # El cliente de la cartera de esta plática (o, en «Probar», el primero con saldo, de ejemplo).
  def customer_for(conversation)
    contact = conversation&.contact
    return Receivables::Summary.customer_for(contact) if contact

    ReceivableCustomer.linked.where(account_id: config.account.id).joins(:receivables)
                      .merge(Receivable.collectable).order(:id).first
  end

  private

  def debt_block(conversation)
    customer = customer_for(conversation)
    return 'LO QUE DEBE: no encontré a este cliente en la cartera. No le digas montos; si pregunta, pásalo al cobrador.' unless customer

    summary = Receivables::Summary.new(customer)
    return "LO QUE DEBE: #{customer.name} no tiene saldo pendiente por cobrar ahora." if summary.invoices.empty?

    "LO QUE DEBE (de la cartera; etapa: #{STAGE_TEXT[summary.stage]}):\n#{summary.text}"
  end

  def payment_block
    payment_info.present? ? "DATOS PARA PAGAR (dalos tal cual):\n#{payment_info}" : 'DATOS PARA PAGAR: no hay; si los pide, pásalo al cobrador.'
  end

  def business_block
    lines = Motor2::Functions::Prospects::BUSINESS.filter_map { |k, label| "- #{label}: #{own_business(k)}" if own_business(k).present? }
    lines.empty? ? '' : "LA EMPRESA:\n#{lines.join("\n")}"
  end
end

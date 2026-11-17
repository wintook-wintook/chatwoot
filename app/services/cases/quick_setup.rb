# frozen_string_literal: true

# «Arma tu cuenta con Dali» — crea tipos de caso con las etapas que se usan en el negocio y
# agrega motivos de cierre. Solo agrega: no cambia ni borra tipos que ya existen (esos se editan
# en Catálogos › Tipos de caso). Opcional: retira los tipos de fábrica que no tienen casos.
#
# Las etapas que se dan son las del avance (las abiertas). Las de espera y resultado (Pospuesta,
# Ganada, Perdida, Cerrado…) salen de la plantilla de la clase, para que los 13 estados queden
# cubiertos como exige Cases::TypeColumnsReplaceService.
#
#   Cases::QuickSetup.new(account, types: [{ 'name' => 'Venta de equipo', 'case_class' => 'commercial',
#                                            'stages' => %w[Contacto Cotización Negociación] }],
#                         reasons: { 'won' => ['Precio'], 'lost' => ['Tiempo de entrega'] },
#                         retire_defaults: true).call
#   → { created: ['Venta de equipo'], reasons: 2, retired: ['Soporte', …] }
class Cases::QuickSetup
  CLASSES = %w[commercial support work_order project].freeze
  MAX_TYPES = 6
  MAX_STAGES = 8
  OUTCOMES = %w[won lost].freeze
  COLORS = %w[#3b82f6 #8b5cf6 #06b6d4 #f59e0b #10b981 #ef4444].freeze

  # Las de espera y resultado ya las pone la plantilla: si vienen en la lista, se quitan.
  FIXED_STAGE = /\A(cierre|cerrad[oa]|ganad[oa]|perdid[oa]|cancelad[oa]|pospuest[oa]|en espera|pausad[oa]|terminad[oa]|resuelt[oa])\b/i

  class Invalid < StandardError; end

  def initialize(account, types:, reasons: {}, retire_defaults: false)
    @account = account
    @types = normalize_types(types)
    @reasons = normalize_reasons(reasons)
    @retire_defaults = retire_defaults
  end

  # Lo que se va a hacer, para la tarjeta (sin tocar nada).
  def problems
    list = []
    list << 'Dime al menos un tipo de caso con sus etapas.' if @types.empty?
    list << "Son muchos tipos: máximo #{MAX_TYPES}." if @types.size > MAX_TYPES
    @types.each do |t|
      list << "Ya hay un tipo de caso llamado «#{t[:name]}»." if existing_names.include?(t[:name].downcase)
      list << "«#{t[:name]}» necesita al menos una etapa." if t[:stages].empty?
    end
    list
  end

  def call
    raise Invalid, problems.first if problems.any?

    ActiveRecord::Base.transaction do
      CaseType.ensure_defaults_for(@account) # que los de fábrica existan antes, para poder retirarlos
      created = @types.each_with_index.map { |t, i| create_type(t, i) }
      { created: created.map(&:name), reasons: add_reasons, retired: retire_defaults }
    end
  end

  # Los tipos de fábrica que se retirarían (no tienen casos).
  def defaults_to_retire
    return [] unless @retire_defaults

    names = CaseType::DEFAULTS.pluck(:name)
    @account.case_types.active.where(name: names).where.not(id: CaseTicket.select(:case_type_id)).pluck(:name)
  end

  attr_reader :types, :reasons

  private

  def normalize_types(types)
    Array(types).filter_map do |raw|
      raw = raw.to_h.stringify_keys
      name = raw['name'].to_s.squish.first(60)
      next if name.blank?

      klass = raw['case_class'].to_s.presence_in(CLASSES) || 'support'
      stages = Array(raw['stages']).map { |s| s.to_s.squish.first(40) }.compact_blank.uniq
                                   .grep_v(FIXED_STAGE).first(MAX_STAGES)
      { name: name, case_class: klass, stages: stages }
    end
  end

  def normalize_reasons(reasons)
    (reasons || {}).to_h.stringify_keys.slice(*OUTCOMES).transform_values do |labels|
      Array(labels).map { |l| l.to_s.squish.first(100) }.compact_blank.uniq.first(10)
    end
  end

  def existing_names = @existing_names ||= @account.case_types.active.pluck(:name).map(&:downcase)

  def create_type(spec, index)
    type = @account.case_types.create!(name: spec[:name], case_class: spec[:case_class],
                                       color: COLORS[index % COLORS.size],
                                       position: @account.case_types.maximum(:position).to_i + 1)
    result = Cases::TypeColumnsReplaceService.new(case_type: type, columns_params: columns_for(type, spec[:stages])).call
    raise Invalid, result.errors.to_sentence unless result.success?

    type
  end

  # Las etapas del avance reemplazan a las abiertas de la plantilla; las de espera y resultado
  # se quedan. La primera etapa toma los estados de la primera abierta; las demás, «en proceso»;
  # la última, lo que sobre de las abiertas.
  def columns_for(type, stages)
    flow, fixed = type.case_type_columns.ordered.to_a.partition { |c| flow?(c) }
    cols = flow_columns(type, stages, Array(flow.first&.statuses))
    leftover = flow.flat_map(&:statuses).uniq - cols.flat_map { |c| c[:statuses] }
    cols.last[:statuses] |= leftover
    (cols + fixed.map { |c| fixed_column(c) }).each_with_index.map { |c, i| c.merge(position: i) }
  end

  def flow_columns(type, stages, first_statuses)
    stages.each_with_index.map do |label, i|
      { label: label, color: COLORS[i % COLORS.size], statuses: i.zero? ? first_statuses.dup : %w[in_progress],
        probability: probability(type, i, stages.size) }
    end
  end

  # Del avance = no es de resultado, de espera del cliente ni de cierre, ni solo de «resuelto».
  NOT_FLOW = %w[waiting_on_customer closed cancelled].freeze
  DONE_ONLY = %w[resolved validating].freeze
  def flow?(column)
    column.outcome.blank? && !column.statuses.intersect?(NOT_FLOW) && (column.statuses - DONE_ONLY).any?
  end

  def fixed_column(col)
    { id: col.id, label: col.label, color: col.color, statuses: col.statuses, outcome: col.outcome,
      probability: col.probability }
  end

  def probability(type, index, total)
    return nil unless type.class_commercial?

    (10 + ((65.0 * index) / [total - 1, 1].max)).round
  end

  def add_reasons
    added = 0
    @reasons.each do |outcome, labels|
      have = @account.case_outcome_reasons.where(outcome: outcome).pluck(:label).map(&:downcase)
      position = @account.case_outcome_reasons.where(outcome: outcome).maximum(:position).to_i
      labels.reject { |l| have.include?(l.downcase) }.each do |label|
        @account.case_outcome_reasons.create!(outcome: outcome, label: label, position: position += 1)
        added += 1
      end
    end
    added
  end

  def retire_defaults
    names = defaults_to_retire
    @account.case_types.where(name: names).find_each { |t| t.update!(retired_at: Time.current) }
    names
  end
end

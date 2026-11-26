# frozen_string_literal: true

# «Agente IA» de la conversación (Plan-Agente-IA-en-Conversaciones): el agente de IA que la está atendiendo AHORA, aparte
# del responsable (que es solo de personas y la IA nunca mueve). Se calcula al consultar —no se guarda—, así nunca queda
# desfasado: sale de los seguimientos vivos de la conversación.
#   - un seguimiento (ContactTracking) pendiente, programado o activo: su agente (Motor 2.0: su función; 1.0: «custom»);
#     el de una campaña gana (es el más específico)
#   - Seguimiento IA (AiFollowUp) activo
# Pausado o terminado = «Sin agente».
#
#   Conversations::AiAttendant.for(conversation)      → { function: 'campaign_seller', name: 'Expo Industrial' } | nil
#   Conversations::AiAttendant.filter(scope, 'with' | 'without' | función)   → las conversaciones de ese filtro
#     with     «Solo agente IA»: la atiende un agente de IA y no tiene responsable
#     without  «Atendidos por personas»: tiene responsable (tenga o no agente de IA)
#     función  las de ese agente (con o sin responsable)
#   Conversations::AiAttendant.counts(scope)          → { 'campaign_seller' => 15, 'customers' => 12, … }
module Conversations::AiAttendant
  TRACKING_LIVE = %w[pending scheduled active].freeze
  FOLLOW_UP = 'follow_up'
  CUSTOM = 'custom' # agentes 1.0 (a medida)

  module_function

  def for(conversation)
    return nil unless conversation&.id

    tracking = live_trackings(conversation.id).first
    return tracking_info(tracking) if tracking&.tracking_campaign_id
    return { function: FOLLOW_UP, name: 'Seguimiento IA' } if AiFollowUp.exists?(conversation_id: conversation.id, status: 'active')

    tracking && tracking_info(tracking)
  end

  def live_trackings(conversation_id)
    ContactTracking.where(conversation_id: conversation_id, status: TRACKING_LIVE)
                   .includes(:tracking_template, :tracking_campaign).order(Arel.sql('tracking_campaign_id IS NULL'), id: :desc)
  end

  def tracking_info(tracking)
    template = tracking.tracking_template
    name = tracking.tracking_campaign&.name.presence || template&.customer_display_name.presence || template&.name
    { function: function_of(template), name: name.to_s }
  end

  def function_of(template)
    return CUSTOM unless template && template.engine.to_s == Motor2::ENGINE.to_s

    template.agent_function.presence || CUSTOM
  end

  # El agente de IA (Motor 2.0) terminó sin entregarla: si nadie la tiene y no queda otro agente, se resuelve sola (no se
  # quedan abiertas para siempre; si el contacto vuelve a escribir, se reabre como siempre). Quita la marca de campaña.
  HANDOFF = /\A(relayed|handed_off)/

  def finished!(tracking)
    conversation = tracking.conversation
    return unless conversation && Motor2.on?(tracking.tracking_template)

    attrs = without_campaign_mark(conversation)
    attrs[:status] = :resolved if resolve?(conversation, tracking)
    conversation.update!(attrs) if attrs.any?
  rescue StandardError => e
    Rails.logger.warn("[Conversations::AiAttendant] finished! #{tracking&.id}: #{e.message}")
  end

  def without_campaign_mark(conversation)
    extra = conversation.additional_attributes.to_h
    extra.key?('ai_campaign') ? { additional_attributes: extra.except('ai_campaign') } : {}
  end

  def resolve?(conversation, tracking)
    conversation.open? && conversation.assignee_id.blank? && !tracking.outcome.to_s.match?(HANDOFF) && self.for(conversation).nil?
  end

  # ---------- filtro y conteos ----------

  TRACKING_SQL = 'EXISTS (SELECT 1 FROM contact_trackings ct %<join>s WHERE ct.conversation_id = conversations.id ' \
                 "AND ct.status IN ('pending', 'scheduled', 'active') %<where>s)"
  FOLLOW_UP_SQL = "EXISTS (SELECT 1 FROM ai_follow_ups f WHERE f.conversation_id = conversations.id AND f.status = 'active')"
  TEMPLATE_JOIN = 'JOIN tracking_templates tt ON tt.id = ct.tracking_template_id'

  def filter(scope, value)
    case value.to_s
    when '', 'all' then scope
    when 'with' then scope.where(assignee_id: nil).where("#{tracking_sql} OR #{FOLLOW_UP_SQL}")
    when 'without' then scope.where.not(assignee_id: nil)
    when FOLLOW_UP then scope.where(FOLLOW_UP_SQL)
    else scope.where(function_sql(value.to_s))
    end
  end

  def tracking_sql(join: '', where: '') = format(TRACKING_SQL, join: join, where: where)

  def function_sql(function)
    engine = ActiveRecord::Base.connection.quote(Motor2::ENGINE.to_s)
    condition = if function == CUSTOM
                  "AND tt.engine <> #{engine}"
                else
                  "AND tt.engine = #{engine} AND tt.agent_function = #{ActiveRecord::Base.connection.quote(function)}"
                end
    tracking_sql(join: TEMPLATE_JOIN, where: condition)
  end

  # Cuántas conversaciones tiene en curso cada agente (para el combo y el menú).
  def counts(scope)
    ids = scope.unscope(:order, :select).select('conversations.id')
    engine = ActiveRecord::Base.connection.quote(Motor2::ENGINE.to_s)
    function = "CASE WHEN tracking_templates.engine = #{engine} THEN COALESCE(tracking_templates.agent_function, '#{CUSTOM}') ELSE '#{CUSTOM}' END"
    by_function = ContactTracking.joins(:tracking_template).where(conversation_id: ids, status: TRACKING_LIVE)
                                 .group(Arel.sql(function)).distinct.count(:conversation_id)
    follow_ups = AiFollowUp.where(conversation_id: ids, status: 'active').distinct.count(:conversation_id)
    follow_ups.positive? ? by_function.merge(FOLLOW_UP => follow_ups) : by_function
  end
end

# frozen_string_literal: true

# ================================================================================
# proyecto@contact_tracking
# ================================================================================
# Servicio: ContactTrackings::KeywordActionService
# Descripción: Evalúa si el contenido de un mensaje coincide con alguna palabra
#              clave de acción configurada en el seguimiento y ejecuta la acción.
#
# Match: exacto, case-insensitive, word-boundary (no substring parcial)
# Acciones soportadas: cancel, pause, objective_met, interested, booked
# Respuesta: silenciosa — NO envía ningún mensaje al contacto
#
# interested / booked: marcan el seguimiento (interested_at / booked_at, que suman a
#             los indicadores Interesados / Agendaron), opcionalmente etiquetan y/o
#             asignan la conversación (label, assignee_id, team_id) y NO cortan el
#             flujo: el bot sigue respondiendo.
#
# Uso:
#   service = ContactTrackings::KeywordActionService.new(tracking, content, 'incoming')
#   service.call  # => true si se ejecutó una acción que corta el flujo
#                 #    (cancel/pause/objective_met), false si no
# ================================================================================

module ContactTrackings
  class KeywordActionService
    VALID_ACTIONS    = %w[cancel pause objective_met interested booked].freeze
    VALID_DIRECTIONS = %w[incoming outgoing both].freeze
    # Acciones que solo marcan el seguimiento y dejan seguir al bot → columna de la marca.
    MARK_COLUMNS = { 'interested' => :interested_at, 'booked' => :booked_at }.freeze

    def initialize(tracking, message_content, direction)
      @tracking  = tracking
      @content   = message_content.to_s
      @direction = direction.to_s
    end

    def call
      matched = matching_rules
      return false if matched.empty?

      marks, terminal = matched.partition { |ka| MARK_COLUMNS.key?(ka['action'].to_s) }
      marks.each { |ka| apply_mark(ka) }

      rule = terminal.first
      return false unless rule

      execute_action(rule['action'], rule['keyword'])
      true
    end

    private

    def matching_rules
      return [] unless @tracking.keyword_actions.is_a?(Array)

      @tracking.keyword_actions.select { |ka| rule_matches?(ka) }
    end

    def rule_matches?(rule)
      return false unless rule.is_a?(Hash)

      keyword   = rule['keyword'].to_s.strip
      action    = rule['action'].to_s
      direction = rule['direction'].to_s

      return false if keyword.blank?
      return false unless VALID_ACTIONS.include?(action)
      return false unless VALID_DIRECTIONS.include?(direction)
      return false unless direction_matches?(direction)

      keyword_present?(keyword)
    end

    def direction_matches?(configured_direction)
      configured_direction == 'both' || configured_direction == @direction
    end

    # Match exacto con word-boundary: no puede estar pegado a letras/dígitos/guión bajo
    def keyword_present?(keyword)
      pattern = /(?<![[:alnum:]_])#{Regexp.escape(keyword)}(?![[:alnum:]_])/i
      @content.match?(pattern)
    end

    def execute_action(action, keyword)
      Rails.logger.info "[KeywordAction] ⌨️  Match '#{keyword}' → #{action} en tracking ##{@tracking.id}"

      performed = case action
                  when 'cancel'
                    @tracking.cancel! if @tracking.can_cancel?
                  when 'pause'
                    @tracking.pause! if @tracking.can_pause?
                  when 'objective_met'
                    @tracking.mark_objective_met! if @tracking.can_complete?
                  end

      record_keyword_fire(action, keyword) if performed
    rescue StandardError => e
      Rails.logger.error "[KeywordAction] ❌ Error ejecutando '#{action}': #{e.message}"
    end

    # Marca el seguimiento (solo la primera vez: el indicador cuenta seguimientos, no
    # disparos) y etiqueta y/o asigna su conversación. La etiqueta, el agente y el
    # equipo se buscan dentro de la cuenta: lo que ya no existe se ignora.
    def apply_mark(rule)
      action = rule['action'].to_s
      column = MARK_COLUMNS[action]
      @tracking.update_column(column, Time.current) if @tracking[column].nil? # rubocop:disable Rails/SkipsModelValidations
      TrackingCampaigns::ProspectScore.call(@tracking) if column == :booked_at # prospeccion P4: agendó cita

      label, assignment = label_and_assign(@tracking.conversation, rule) if @tracking.conversation

      Rails.logger.info "[KeywordAction] ⌨️  Match '#{rule['keyword']}' → #{action} en tracking ##{@tracking.id} " \
                        "(label: #{label || '-'}, #{assignment.presence || 'sin asignación'})"
    rescue StandardError => e
      Rails.logger.error "[KeywordAction] ❌ Error ejecutando '#{action}': #{e.message}"
    end

    def label_and_assign(conversation, rule)
      label = mark_label(conversation.account, rule)
      conversation.add_labels([label]) if label
      assignment = mark_assignment(conversation.account, rule)
      conversation.update!(assignment) if assignment.any?
      [label, assignment]
    end

    def mark_label(account, rule)
      title = rule['label'].to_s.strip
      title if title.present? && account.labels.exists?(title: title)
    end

    def mark_assignment(account, rule)
      agent = account.users.find_by(id: rule['assignee_id']) if rule['assignee_id'].present?
      team  = account.teams.find_by(id: rule['team_id']) if rule['team_id'].present?
      { assignee_id: agent&.id, team_id: team&.id }.compact
    end

    # Atribución para KPIs de reglas: guarda qué regla disparó y cerró/pausó el
    # seguimiento. update_column: campo aislado, ya persistido por la acción.
    def record_keyword_fire(action, keyword)
      @tracking.update_column(:keyword_action_fired, {
        keyword:   keyword,
        action:    action,
        direction: @direction,
        fired_at:  Time.current.iso8601
      })
    end
  end
end

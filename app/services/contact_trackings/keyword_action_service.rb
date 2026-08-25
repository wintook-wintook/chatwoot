# frozen_string_literal: true

# ================================================================================
# proyecto@contact_tracking
# ================================================================================
# Servicio: ContactTrackings::KeywordActionService
# Descripción: Evalúa si el contenido de un mensaje coincide con alguna palabra
#              clave de acción configurada en el seguimiento y ejecuta la acción.
#
# Match: exacto, case-insensitive, word-boundary (no substring parcial)
# Acciones soportadas: cancel, pause, objective_met
# Respuesta: silenciosa — NO envía ningún mensaje al contacto
#
# Uso:
#   service = ContactTrackings::KeywordActionService.new(tracking, content, 'incoming')
#   service.call  # => true si se ejecutó una acción, false si no hubo match
# ================================================================================

module ContactTrackings
  class KeywordActionService
    VALID_ACTIONS    = %w[cancel pause objective_met].freeze
    VALID_DIRECTIONS = %w[incoming outgoing both].freeze

    def initialize(tracking, message_content, direction)
      @tracking  = tracking
      @content   = message_content.to_s
      @direction = direction.to_s
    end

    def call
      return false unless @tracking.keyword_actions.is_a?(Array)
      return false if @tracking.keyword_actions.empty?

      matched = @tracking.keyword_actions.find do |ka|
        next false unless ka.is_a?(Hash)

        keyword   = ka['keyword'].to_s.strip
        action    = ka['action'].to_s
        direction = ka['direction'].to_s

        next false if keyword.blank?
        next false unless VALID_ACTIONS.include?(action)
        next false unless VALID_DIRECTIONS.include?(direction)
        next false unless direction_matches?(direction)

        keyword_present?(keyword)
      end

      return false unless matched

      execute_action(matched['action'], matched['keyword'])
      true
    end

    private

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

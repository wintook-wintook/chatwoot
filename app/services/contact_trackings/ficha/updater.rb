# frozen_string_literal: true

# ================================================================================
# feat/ficha_agente_ia — GUARDAR LA FICHA DE UN AGENTE QUE YA EXISTE
# ================================================================================
# «Guardar ficha» en Recursos: datos del agente, lo marcado, canal y seguimiento, agenda, archivos, reglas,
# y —en el Entrenamiento— bienvenida y preguntas. Si el Entrenamiento cambia, pasa antes
# por el comprobador: con un bloqueo no se guarda nada (regresa los hallazgos).
# ================================================================================

class ContactTrackings::Ficha::Updater
  def initialize(template, params, items:)
    @template = template
    @params = params
    @items = items
    @settings = ContactTrackings::Ficha::Settings.new(params)
  end

  # nil si se guardó; los hallazgos que bloquean si no.
  def call
    texto = prompt
    if texto != @template.complementary_prompt.to_s
      validacion = ContactTrackings::Assistant::ValidatorService.new(texto, account: @template.account).call
      return validacion[:blocking] unless validacion[:valid]
    end

    @template.update!(attributes.merge(complementary_prompt: texto))
    nil
  end

  private

  def calendar_ids = @items.filter_map { |i| i['key'][/\Acalendar:(\d+)\z/, 1]&.to_i }

  def attributes
    { resources: resources, calendar_integration_ids: calendar_ids, keyword_actions: @settings.keyword_actions,
      version_note: 'Ficha actualizada' }.compact.merge(@settings.agenda(calendar_ids)).merge(@settings.follow_up).merge(channel).merge(profile)
  end

  # Datos del agente (Recursos › Agente y canal). El nombre y el objetivo no se borran.
  PROFILE_FIELDS = { name: 100, customer_display_name: 30, objective: 500, ai_context: 5000 }.freeze
  REQUIRED_FIELDS = %i[name objective].freeze

  def profile
    PROFILE_FIELDS.each_with_object({}) do |(campo, tope), cambios|
      next unless @params.key?(campo)

      valor = @params[campo].to_s.strip.first(tope)
      next if valor.blank? && REQUIRED_FIELDS.include?(campo)

      cambios[campo] = valor.presence
    end
  end

  def resources
    { 'items' => @items, 'confirmed_at' => Time.current.iso8601,
      'files' => @settings.file_rules || @template.file_rules, 'attempts' => attempts }.compact
  end

  def attempts
    pedido = @params[:attempts].to_i
    pedido.positive? ? pedido.clamp(1, 10) : @template.resources['attempts']
  end

  def channel
    cambios = {}
    cambios[:inbox_id] = @template.account.inboxes.find_by(id: @params[:inbox_id])&.id if @params.key?(:inbox_id)
    cambios
  end

  # Bienvenida y preguntas se escriben en el Entrenamiento.
  def prompt
    texto = @template.complementary_prompt.to_s
    texto = ContactTrackings::Ficha::PromptEditor.new(texto).replace_welcome(@params[:welcome]).text if @params.key?(:welcome)
    return texto unless @params.key?(:questions)

    preguntas = ContactTrackings::Ficha::Questions.clean(@params[:questions])
    ContactTrackings::Ficha::Questions.new(texto).write(preguntas, @params[:questions_when].to_s).text
  end
end

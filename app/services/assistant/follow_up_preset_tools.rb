# frozen_string_literal: true

# Asistente (Dali) — plantillas de seguimiento: listarlas y proponer guardar una (la «receta»
# de un Seguimiento IA). Usarlas al delegar va en FollowUpTools (argumento preset). Se incluye
# en Assistant::Tools; lo confirmado lo guarda Assistant::FollowUpPresetRunner.
module Assistant::FollowUpPresetTools
  FOLLOW_UP_PRESET_READ_TOOLS = %w[follow_up_presets].freeze
  FOLLOW_UP_PRESET_PROPOSAL_TOOLS = %w[propose_save_follow_up_preset].freeze

  def tool_follow_up_presets(args)
    query = args['query'].to_s.strip.downcase
    presets = @account.ai_follow_up_presets.ordered.to_a
    presets = presets.select { |p| "#{p.name} #{p.objective}".downcase.include?(query) } if query.present?
    { presets: presets.first(30).map { |p| { name: p.name, summary: p.summary } }, total: presets.size }
  end

  def prepare_save_follow_up_preset(args)
    name = args['name'].to_s.squish.first(80)
    raise ArgumentError, 'Dime con qué nombre la guardo.' if name.blank?
    raise ArgumentError, 'Falta qué debe lograr el seguimiento.' if args['objective'].blank?
    raise ArgumentError, "Ya hay una plantilla de seguimiento llamada «#{name}»." if preset_named?(name)

    payload = preset_payload(name, args)
    [payload, { 'rows' => [['NAME', name], ['OBJECTIVE', payload['objective'].first(120)]] }]
  end

  private

  def preset_payload(name, args)
    { 'name' => name, 'objective' => args['objective'].to_s.first(1000), 'instructions' => args['instruction'].to_s,
      'max_attempts' => (args['max_attempts'].presence || 3).to_i.clamp(1, 10),
      'interval_value' => [args['interval_value'].to_i, 1].max,
      'interval_unit' => args['interval_unit'].presence_in(AiFollowUp::UNITS) || 'days',
      'template_name' => args['template_name'].presence }.compact
  end

  def preset_named?(name)
    @account.ai_follow_up_presets.exists?(['lower(name) = ?', name.downcase])
  end
end

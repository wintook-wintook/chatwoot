# frozen_string_literal: true

# Motor 2.0 — las funciones de agente (Plan-Motor-Agentes.md §11.14): «Atención a prospectos»,
# «Atención a clientes», «Cobranza»… Todas usan el mismo motor; cada una trae su puesto, las
# habilidades que lleva y su asistente (wizard). El catálogo son archivos globales
# (config/agent_functions/<función>.yml + .md del puesto): si mejoramos uno, mejora para todas
# las empresas. Los que aún no están salen como «Próximamente».
#
# Un agente sabe su función por tracking_templates.agent_function; lo que contestó en el asistente
# vive en motor2['answers'] y la clase de la función (Motor2::Functions::Prospects…) lo convierte
# en prompt y habilidades en cada turno.
module Motor2::Functions
  DIR = Rails.root.join('config/agent_functions')
  CUSTOM = 'custom'
  CLASSES = { 'prospects' => 'Motor2::Functions::Prospects', 'customers' => 'Motor2::Functions::Customers' }.freeze

  module_function

  # [{ key:, title:, summary:, available: }] en el orden del catálogo.
  def all
    catalog.values.sort_by { |e| e['order'].to_i }.map do |e|
      { key: e['key'], title: e['title'], summary: e['summary'], available: available?(e['key']) }
    end
  end

  def entry(key) = catalog[key.to_s]

  def title(key) = entry(key)&.dig('title')

  def available?(key) = CLASSES.key?(key.to_s) && entry(key)&.dig('available') == true

  # El texto del puesto (va en el prompt, antes de lo de la empresa).
  def puesto(key)
    path = DIR.join("#{key}.md")
    path.exist? ? File.read(path).strip : ''
  end

  # La función del agente (con sus respuestas) o nil si es a medida o 1.0.
  def for(config)
    klass = CLASSES[config.template.agent_function.to_s]
    klass&.constantize&.new(config)
  end

  def klass(key) = CLASSES[key.to_s]&.constantize

  def catalog
    @catalog = nil if Rails.env.development?
    @catalog ||= Dir[DIR.join('*.yml')].to_h do |path|
      data = YAML.safe_load(File.read(path)) || {}
      [data['key'].to_s, data]
    end
  end
end

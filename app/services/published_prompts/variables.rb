# frozen_string_literal: true

# ================================================================================
# proyecto@adaptar_prompts_publicados (F4) — LOS DATOS DEL NEGOCIO DEL AUTOR, COMO VARIABLES
# ================================================================================
# El agente del autor está vivo: no puede tener <PENDIENTE:> (el comprobador no lo deja
# guardar, B9). Entonces las variables se marcan AL PUBLICAR: el autor dice qué textos
# son de su negocio y cómo se llaman, y la COPIA PUBLICADA los lleva como marcas:
#
#   [{ 'text' => 'Grúas del Norte', 'label' => 'Nombre del negocio' }]
#   «Eres el asistente de Grúas del Norte.» → «Eres el asistente de <PENDIENTE: Nombre del negocio>.»
#
# Quien lo baja las llena en la pestaña «Configurar» (AdaptationInventory las agrupa por
# nombre). El agente del autor no cambia.
#
# Solo se reemplaza en el Entrenamiento (`prompt`), no en Contexto ni Objetivo: la
# pestaña «Configurar» edita el Entrenamiento, y una marca que no se puede llenar desde
# ahí dejaría la copia bloqueada para siempre (ContactTrackings::PendingSetup).
#
# Nunca dentro de una directiva ({{doc:Grúas}}, @buscar_foro(Grúas)), de una línea
# @ruta ni de otra marca: ahí el texto es un nombre que el motor busca, no prosa. Sin
# distinguir mayúsculas; los textos largos primero, así «Grúas del Norte» gana sobre
# «Grúas».
# Plan: docs/adaptar_prompts_publicados_plan.md
# ================================================================================

module PublishedPrompts::Variables
  class Invalid < StandardError; end

  MAX = 30
  TEXT_LENGTH = (3..200)
  LABEL_RE = /\A[^<>\n]{1,60}\z/

  # Lo que no se toca: directivas, líneas @ruta y marcas <PENDIENTE:>.
  PROTECTED_RE = /
    \{\{[^}]*\}\}                                              |
    @[a-z_]+\([^)\n]*\)                                        |
    ^[ \t]*@ruta[^\n]*$                                        |
    #{ContactTrackings::Assistant::PendingMarkers::RE.source}
  /ix

  module_function

  # [{ 'text', 'label' }] limpias: sin vacías, sin repetidas (por texto), hasta MAX.
  def normalize(list)
    limpias = Array(list).filter_map { |variable| clean(variable) }
    limpias.uniq { |v| v['text'].downcase }.first(MAX)
  end

  def clean(variable)
    variable = variable.to_unsafe_h if variable.respond_to?(:to_unsafe_h)
    return unless variable.is_a?(Hash)

    datos = variable.with_indifferent_access
    text = datos[:text].to_s.squish
    { 'text' => text, 'label' => datos[:label].to_s.squish } if text.present?
  end

  # Cuántas veces aparece en la prosa (fuera de lo protegido).
  def count(text, needle)
    prose(text).sum { |pieza| pieza.scan(pattern(needle)).size }
  end

  def apply(text, variables)
    ordered = variables.sort_by { |v| -v['text'].size }
    ordered.reduce(text.to_s) do |actual, variable|
      replace_in_prose(actual, variable['text'], "<PENDIENTE: #{variable['label']}>")
    end
  end

  # Lo que impide publicar, en el idioma de quien publica. [] si todo bien.
  def problems(variables, prompt)
    variables.filter_map do |variable|
      next I18n.t('published_prompts.variables.text_length', text: variable['text']) unless TEXT_LENGTH.cover?(variable['text'].size)
      next I18n.t('published_prompts.variables.label_invalid', text: variable['text']) unless variable['label'].match?(LABEL_RE)
      next I18n.t('published_prompts.variables.not_found', text: variable['text']) if count(prompt, variable['text']).zero?
    end
  end

  def validate!(variables, prompt)
    errores = problems(variables, prompt)
    raise Invalid, errores.join(' · ') if errores.any?
  end

  # Partido en [prosa, protegido, prosa, protegido, …]: las posiciones pares son prosa.
  def pieces(text)
    text.to_s.split(/(#{PROTECTED_RE.source})/ix)
  end

  def prose(text)
    pieces(text).each_with_index.filter_map { |pieza, i| pieza if i.even? }
  end

  def replace_in_prose(text, needle, replacement)
    pieces(text).each_with_index.map do |pieza, i|
      i.even? ? pieza.gsub(pattern(needle)) { replacement } : pieza
    end.join
  end

  def pattern(needle)
    /#{Regexp.escape(needle)}/i
  end
end

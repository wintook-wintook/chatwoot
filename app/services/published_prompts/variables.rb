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
# @ruta, de otra marca, de la llave de una ruta en [ALCANCE POR RAMA] («- kontrolya:») ni
# de una #etiqueta: ahí el texto es un nombre que el motor busca, no prosa. Sin
# distinguir mayúsculas; los textos largos primero, así «Grúas del Norte» gana sobre
# «Grúas».
#
# feat/reemplazo_directo_variables: en la pestaña «Configurar» una variable puede traer
# `value` y entonces se escribe ese valor en lugar de la marca (un paso, sin dejar al
# agente bloqueado). Al publicar nunca lleva valor: la copia necesita la marca.
# Plan: docs/adaptar_prompts_publicados_plan.md
# ================================================================================

module PublishedPrompts::Variables
  class Invalid < StandardError; end

  MAX = 30
  TEXT_LENGTH = (3..200)
  LABEL_RE = /\A[^<>\n]{1,60}\z/
  VALUE_MAX = ContactTrackings::Assistant::AdaptationApplier::MAX_VALUE

  # Lo que no se toca: directivas, líneas @ruta, marcas <PENDIENTE:>, la llave de una ruta
  # al inicio de su línea («- kontrolya:») y las #etiquetas.
  PROTECTED_RE = /
    \{\{[^}]*\}\}                                              |
    @[a-z_]+\([^)\n]*\)                                        |
    ^[ \t]*@ruta[^\n]*$                                        |
    ^[ \t]*-[ \t]*[a-z0-9_]+(?=[ \t]*:)                        |
    \#[[:alnum:]_-]+                                           |
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
    return if text.blank?

    limpia = { 'text' => text, 'label' => datos[:label].to_s.squish }
    value = datos[:value].to_s.squish
    value.present? ? limpia.merge('value' => value) : limpia
  end

  # Cuántas veces aparece en la prosa (fuera de lo protegido).
  def count(text, needle)
    prose(text).sum { |pieza| pieza.scan(pattern(needle)).size }
  end

  # Primero cada texto pasa a una ficha (\u0001n\u0001) y al final las fichas a su valor:
  # así un texto corto no vuelve a reemplazarse dentro del valor que dejó uno largo
  # («Grúas» dentro de «Grúas del Sur»).
  def apply(text, variables)
    ordered = variables.sort_by { |v| -v['text'].size }
    con_fichas = ordered.each_with_index.reduce(text.to_s) do |actual, (variable, i)|
      replace_in_prose(actual, variable['text'], "\u0001#{i}\u0001")
    end
    con_fichas.gsub(/\u0001(\d+)\u0001/) do
      variable = ordered[Regexp.last_match(1).to_i]
      variable['value'].presence || "<PENDIENTE: #{variable['label']}>"
    end
  end

  # Lo que impide publicar, en el idioma de quien publica. [] si todo bien.
  def problems(variables, prompt)
    variables.filter_map do |variable|
      next I18n.t('published_prompts.variables.text_length', text: variable['text']) unless TEXT_LENGTH.cover?(variable['text'].size)
      next I18n.t('published_prompts.variables.label_invalid', text: variable['text']) unless variable['label'].match?(LABEL_RE)
      next I18n.t('published_prompts.variables.not_found', text: variable['text']) if count(prompt, variable['text']).zero?
      next I18n.t('published_prompts.variables.value_invalid', text: variable['text']) unless value_ok?(variable['value'])
    end
  end

  # Sin valor es una marca. Con valor, ni muy largo ni otra marca dentro.
  def value_ok?(value)
    return true if value.nil?

    value.size <= VALUE_MAX && !ContactTrackings::Assistant::PendingMarkers.pending?(value)
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

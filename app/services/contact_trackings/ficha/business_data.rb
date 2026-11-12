# frozen_string_literal: true

# ================================================================================
# feat/ficha_agente_ia — DATOS DEL NEGOCIO (DATOS FIJOS QUE NO SON PREGUNTAS)
# ================================================================================
# Pedido del usuario (10/11/2026): «los valores fijos son constantes… nombre de la
# empresa, nombre del agente, valores que después se podrían cambiar pero no en la
# conversación… el motor ya lo tiene, el asistente solo tiene las preguntas».
#
#   [DATOS FIJOS]                        [DATOS DEL NEGOCIO]
#   EMPRESA = Kontrolya                  - Empresa: %EMPRESA%
#   LIGA_PARA_AGENDAR (liga) = https://… - Liga para agendar: %LIGA_PARA_AGENDAR%
#
# El motor sustituye %NOMBRE% antes de mandar el texto al modelo (PromptConstants), que
# nunca ve [DATOS FIJOS]: por eso cada dato se cita en [DATOS DEL NEGOCIO], y así el
# agente los tiene a la mano. Cambiar el teléfono = cambiarlo aquí. Los demás datos fijos
# (preguntas, los escritos a mano) no se tocan.
# ================================================================================

class ContactTrackings::Ficha::BusinessData
  include ContactTrackings::Ficha::SectionLines

  SECTION = 'DATOS DEL NEGOCIO'
  CONSTANTS = 'DATOS FIJOS'
  MAX = 15
  MAX_LABEL = 40
  MAX_VALUE = 300
  LINE_RE = /\A\s*-\s*(.+?):\s*%(#{ContactTrackings::PromptConstants::NAME})%\s*\z/o
  URL_RE = %r{\Ahttps?://\S+\z}i

  # [{ 'label', 'value' }] limpias (sin vacíos ni etiquetas repetidas).
  def self.clean(lista)
    limpios = Array(lista).first(MAX).filter_map { |dato| clean_one(dato) }
    limpios.uniq { |d| d['label'].downcase }
  end

  def self.clean_one(dato)
    h = (dato.respond_to?(:to_unsafe_h) ? dato.to_unsafe_h : dato.to_h).stringify_keys
    etiqueta = h['label'].to_s.tr(':%', '  ').squish.first(MAX_LABEL)
    valor = h['value'].to_s.delete('%').squish.first(MAX_VALUE)
    return nil if etiqueta.blank? || valor.blank?

    { 'label' => etiqueta, 'value' => valor }
  end

  def initialize(text)
    @lines = text.to_s.split("\n", -1)
  end

  # [{ 'label', 'value', 'name' }]
  def read
    constantes = ContactTrackings::PromptConstants.parse(text)
    section_body(SECTION).filter_map do |linea|
      m = linea.match(LINE_RE)
      next unless m && constantes[m[2]]

      { 'label' => m[1].strip, 'value' => constantes[m[2]][:value].to_s, 'name' => m[2] }
    end
  end

  def write(datos)
    viejos = read.pluck('name')
    drop_lines(CONSTANTS) { |l| (m = l.match(ContactTrackings::PromptConstants::DECL_RE)) && viejos.include?(m[1]) }
    drop_if_empty(CONSTANTS)
    drop_section(SECTION)
    return self if datos.empty?

    nombres = names_for(datos)
    append_lines(CONSTANTS, datos.each_with_index.map { |d, i| declaration(nombres[i], d['value']) })
    append_lines(SECTION, datos.each_with_index.map { |d, i| "- #{d['label']}: %#{nombres[i]}%" })
    self
  end

  private

  def declaration(nombre, valor)
    valor.match?(URL_RE) ? "#{nombre} (liga) = #{valor}" : "#{nombre} = #{valor}"
  end

  # EMPRESA, TELEFONO… sin chocar con otros datos fijos (Q1, los escritos a mano).
  def names_for(datos)
    usados = ContactTrackings::PromptConstants.parse(text).keys.map(&:upcase)
    datos.each_with_index.map do |dato, indice|
      base = I18n.transliterate(dato['label']).upcase.gsub(/[^A-Z0-9]+/, '_').gsub(/\A[_0-9]+|_+\z/, '').first(30)
      base = "DATO_#{indice + 1}" if base.blank?
      nombre = base
      n = 2
      while usados.include?(nombre)
        nombre = "#{base}_#{n}"
        n += 1
      end
      usados << nombre
      nombre
    end
  end
end

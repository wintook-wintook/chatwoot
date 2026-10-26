# frozen_string_literal: true

# ================================================================================
# proyecto@publicar_prompts — QUÉ TIENE QUE CONFIGURAR QUIEN BAJE EL PROMPT
# ================================================================================
# Las directivas del prompt apuntan a recursos de la cuenta del autor (sus archivos, sus
# hojas, sus consultas al ERP, sus calendarios). Al publicar NO se reescriben: se dejan
# en el texto y se listan aquí, para que la Galería y el agente bajado digan "esto
# tienes que configurar en tu cuenta".
#
# Las expresiones se toman de donde vive cada directiva (no se copian), así una
# directiva que cambie de forma se sigue detectando igual que en el motor.
#
# Devuelve [{ 'kind' => 'google_sheet', 'name' => 'precios' }, …] sin repetidos, en el
# orden en que aparecen las clases de directiva.
# ================================================================================

module PublishedPrompts::Requirements
  # Directivas de búsqueda del motor que dependen de algo configurado en la cuenta.
  # :sheet_lookup se resuelve aparte para quedarse solo con el nombre de la hoja.
  SEARCH_KINDS = %i[google_doc google_sheet knowledge_source discourse_integration contpaq_support article].freeze

  # Directivas sin nombre: con que aparezcan, piden algo de la cuenta.
  FLAGS = [
    [/@agendar_calendar\b/i, 'calendar'],
    [/@buscar_predefinidas\b/i, 'canned_responses']
  ].freeze

  module_function

  def detect(*texts)
    text = texts.compact.join("\n")
    return [] if text.blank?

    (search_directives(text) + sheet_lookups(text) + erp_queries(text) + attachments(text) + flags(text)).uniq
  end

  def search_directives(text)
    KnowledgeBase::Directives::SEARCH_DIRECTIVES.flat_map do |regex, kind, named|
      next [] unless SEARCH_KINDS.include?(kind)

      if named
        text.scan(regex).map { |captura| item(kind, Array(captura).first) }
      else
        text.match?(regex) ? [item(kind)] : []
      end
    end
  end

  # {{hoja_buscar: Hoja | col=valores | regresar}} → la hoja es lo que hay antes del primer |.
  def sheet_lookups(text)
    text.scan(ContactTrackings::SheetLookup::DIRECTIVE_RE).map do |(cuerpo)|
      item('google_sheet', cuerpo.to_s.split('|').first)
    end
  end

  # {{consulta:conexion/nombre(args)}} → "conexion/nombre" (o solo el nombre).
  def erp_queries(text)
    text.to_enum(:scan, ExternalDb::ConsultaDirectiveRenderer::DIRECTIVE).map do
      m = Regexp.last_match
      item('erp_query', [m[:conn], m[:name]].compact.join('/'))
    end
  end

  # {{nombre}} sin dos puntos = archivo de la pestaña Archivos del agente.
  def attachments(text)
    text.scan(ContactTrackings::AgentAttachments::DIRECTIVE).map { |(nombre)| item('attachment', nombre) }
  end

  def flags(text)
    FLAGS.filter_map { |regex, kind| item(kind) if text.match?(regex) }
  end

  def item(kind, name = nil)
    { 'kind' => kind.to_s, 'name' => name.to_s.strip.presence }.compact
  end
end

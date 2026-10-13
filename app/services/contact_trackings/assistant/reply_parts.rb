# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — LO QUE ESCRIBIÓ EL AGENTE Y LO QUE AGREGÓ EL SISTEMA (P2 · 3.4a)
# ================================================================================
# La respuesta que ve el cliente no la escribe toda el modelo. El motor le pega:
#   · la #etiqueta de la ruta (with_branch_tag)
#   · la firma: «-TB» o «_Nombre de la fuente_»
#   · el enlace del foro: «📚 Más información: …» o «🔎 Tema relacionado que quizá te sirva: …»
#   · mensajes enteros armados por código: los horarios del calendario, la lista de
#     servicios («Recibí 1 servicio: …») y el aviso de caso («Tu caso 01168 fue registrado…»)
#
# El juez de F0 (13/10/2026) calificaba todo como si lo hubiera escrito el agente: marcó
# los horarios reales del calendario como «inventados» y contó la etiqueta como línea.
# Aquí se separa: el estilo se mide solo en lo que escribió el modelo.
# ================================================================================

class ContactTrackings::Assistant::ReplyParts
  TAG_LINE_RE = /\A(?:#[a-z0-9_]+\s*)+\z/i
  SIGNATURE_RE = /\A(?:-TB|_[^_\n]+_)\z/
  FORUM_RE = /\A(?:📚 Más información|🔎 Tema relacionado que quizá te sirva):/
  # Mensajes que arma el código de principio a fin: desde su encabezado hasta el final del mensaje.
  SYSTEM_STARTS = {
    /\A¡Con gusto! 📅 Tenemos los siguientes horarios/ => 'horarios del calendario',
    /\A(?:Recibí|Actualicé) \d+ servicios?\b/ => 'lista de servicios',
    /\A(?:Tu caso \S+ fue registrado|Ya tienes el caso \S+ en curso)\b/ => 'aviso de caso registrado'
  }.freeze

  attr_reader :added

  # mensajes: los mensajes salientes, uno por uno (o todos juntos en un texto).
  def initialize(mensajes)
    @body = []
    @added = []
    Array(mensajes).each { |mensaje| split(mensaje.to_s) }
  end

  def body = @body.join("\n\n")

  def blank? = @body.empty? && @added.empty?

  # «horarios del calendario», «etiqueta #soporte»… sin repetir.
  def added_labels = @added.pluck('que').uniq

  private

  def split(mensaje)
    sistema = nil
    paragraphs(mensaje).each do |parrafo|
      que = kind(parrafo)
      if que.nil? && sistema
        sistema['texto'] += "\n\n#{parrafo}"
      elsif que.nil?
        @body << parrafo
      else
        parte = add(que, parrafo)
        sistema = SYSTEM_STARTS.value?(que) ? parte : nil
      end
    end
  end

  def kind(parrafo)
    return 'firma' if parrafo.match?(SIGNATURE_RE)
    return 'enlace del foro' if parrafo.match?(FORUM_RE)

    SYSTEM_STARTS.find { |re, _| parrafo.match?(re) }&.last
  end

  # Las líneas que son solo #etiquetas salen aparte, aunque vengan pegadas al texto.
  def paragraphs(mensaje)
    limpio = mensaje.lines.map do |linea|
      next linea unless linea.strip.match?(TAG_LINE_RE)

      add("etiqueta #{linea.strip}", linea.strip)
      "\n"
    end.join
    limpio.split(/\n[ \t]*\n/).map(&:strip).reject(&:empty?)
  end

  def add(que, texto)
    { 'que' => que, 'texto' => texto }.tap { |parte| @added << parte }
  end
end

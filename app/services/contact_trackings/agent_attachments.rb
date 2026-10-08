# frozen_string_literal: true

# ================================================================================
# proyecto@ai_agent_attachments — {{nombre}} EN LA RESPUESTA → ARCHIVO DEL AGENTE IA
# ================================================================================
# El modelo escribe {{imagen_promo2}} en su respuesta y el motor lo cambia por el
# archivo subido con ese nombre en la pestaña "Archivos" del Agente IA.
#
# Gemelo de ContactTrackingResponseAnalyzerJob#resolve_attachment_directives (ramas SIN
# fuente), para las ramas CON fuente, que contestan por KnowledgeBaseResponseService: ahí
# el token salía como texto literal al cliente. Justo el caso que más se pide: el nombre
# del archivo vive en una columna de la hoja (cuenta 568, «imagen promocion» en CATALOGO
# DE CARRERAS, 30/09/2026). Mismo patrón, mismo tope y misma limpieza que el job: si se
# cambia uno, se cambia el otro. El job no se tocó porque su archivo arrastra ofensas de
# rubocop previas y el pre-commit revisa el archivo entero.
# ================================================================================

module ContactTrackings::AgentAttachments
  DIRECTIVE = /\{\{\s*([a-zA-Z0-9_-]+)\s*\}\}/
  MAX = ENV.fetch('AI_AGENT_MAX_ATTACHMENTS', '5').to_i

  HINT = 'ENVÍO DE ARCHIVOS: Para enviar un archivo al cliente, escribe la directiva EXACTA (por ejemplo ' \
         '{{nombre}}) dentro de tu respuesta, tal cual y sin comillas; el sistema la sustituirá por el archivo ' \
         'adjunto. No la describas ni la traduzcas. Si el nombre del archivo viene en la información ' \
         'consultada, cópialo sin cambiarle nada.'

  module_function

  # [texto_limpio, signed_ids]. Reutiliza el blob existente (signed_id → MessageBuilder):
  # no se duplica el archivo en cada envío. Un nombre que el agente no tiene se quita
  # igual del texto: el cliente nunca debe ver un {{…}}.
  def resolve(template, content)
    names = content.to_s.scan(DIRECTIVE).flatten
    return [content, []] if names.blank? || template.nil?

    [clean(content), signed_ids(template, names)]
  end

  # Lo que se guarda en el historial: si el token queda tal cual, el modelo lo imita
  # y reenvía el archivo en cada turno. Así sabe que ya lo mandó.
  def for_history(content)
    content.to_s.gsub(DIRECTIVE) { "(archivo enviado: #{Regexp.last_match(1)})" }
  end

  # Solo si el agente tiene archivos: a los demás no se les suma texto al prompt.
  def hint(template)
    template&.ai_agent_attachments&.exists? ? HINT : nil
  end

  def signed_ids(template, names)
    names.uniq.each_with_object([]) do |name, ids|
      break ids if ids.size >= MAX

      attachment = template.ai_agent_attachments.where('LOWER(name) = ?', name.downcase).first
      if attachment&.file&.attached?
        ids << attachment.file.blob.signed_id
      else
        Rails.logger.warn "[AgentAttachments] 📎 {{#{name}}} no encontrado en Agente IA ##{template.id}"
      end
    end
  end

  # {{ }} es autodelimitado, así que no queda extensión colgada.
  def clean(content)
    content.gsub(DIRECTIVE, '')
           .gsub(/[ \t]{2,}/, ' ')
           .gsub(/ +([.,;:!?])/, '\1')
           .gsub(/\n{3,}/, "\n\n")
           .strip
  end
end

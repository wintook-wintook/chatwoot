# ================================================================================
# proyecto@ai_agent_attachments
# ================================================================================
# Servicio: AiAgentAttachments::DirectiveReferenceService
# Descripción: mantiene "vivas" las referencias {{nombre}} cuando un adjunto
#   de un Agente IA se renombra o se borra. Reescribe el token en:
#     (a) el prompt complementario del propio Agente IA (TrackingTemplate), y
#     (b) los prompts congelados de los seguimientos VIVOS que referencian ese agente
#         (el prompt se copia al crear el seguimiento, así que hay que actualizarlo ahí).
#   Así la resolución sigue funcionando por nombre legible, sin divergencias.
# ================================================================================

module AiAgentAttachments
  class DirectiveReferenceService
    # Estados de seguimiento que aún pueden enviar mensajes (mismo criterio que el
    # índice único de ContactTracking). Los finalizados (completed/cancelled/failed)
    # ya no envían, así que no se tocan.
    LIVE_STATUSES = %w[pending scheduled active paused].freeze

    class << self
      # Renombra {{old_name}} → {{new_name}} en el agente y sus seguimientos vivos.
      def rename(template, old_name, new_name)
        return if template.nil? || old_name.blank? || new_name.blank? || old_name == new_name

        replacement = "{{#{new_name}}}"
        rewrite(template, old_name) { |text| text.gsub(directive_regex(old_name), replacement) }
      end

      # Elimina las referencias {{name}} colgantes tras borrar el adjunto.
      def remove(template, name)
        return if template.nil? || name.blank?

        rewrite(template, name) { |text| tidy(text.gsub(directive_regex(name), '')) }
      end

      private

      # Token exacto {{name}} (admite espacios internos: {{ name }}). El `\}\}` justo tras
      # el nombre evita tocar slugs más largos con el mismo prefijo ({{cat}} vs {{catalogo}}).
      def directive_regex(name)
        /\{\{\s*#{Regexp.escape(name)}\s*\}\}/i
      end

      def rewrite(template, name)
        # (a) Prompt del Agente IA
        prompt = template.complementary_prompt.to_s
        if prompt.match?(directive_regex(name))
          new_prompt = yield(prompt)
          template.update_columns(complementary_prompt: new_prompt) if new_prompt != prompt
        end

        # (b) Seguimientos vivos que copiaron el prompt. El LIKE es un prefiltro coarse
        # (lo reconfirma la regex); por eso usamos la forma canónica {{name}}.
        ContactTracking
          .where(tracking_template_id: template.id, status: LIVE_STATUSES)
          .where('complementary_prompt LIKE ?', "%{{#{name}}}%")
          .find_each do |tracking|
            current = tracking.complementary_prompt.to_s
            updated = yield(current)
            tracking.update_columns(complementary_prompt: updated) if updated != current
          end
      end

      # Limpieza mínima de espacios sobrantes al quitar un token (sin alterar estructura).
      def tidy(text)
        text.gsub(/[ \t]{2,}/, ' ')
            .gsub(/ +([.,;:!?])/, '\1')
            .gsub(/\n{3,}/, "\n\n")
      end
    end
  end
end

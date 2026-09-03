# frozen_string_literal: true

# ================================================================================
# proyecto@contact_tracking — CATÁLOGO ÚNICO DE DIRECTIVAS DE FUENTE
# ================================================================================
# Esta cadena vivía DUPLICADA en KnowledgeBaseResponseService#detect_search_directive
# y en ContactTrackingResponseAnalyzerJob#kbase_available?. Las dos copias divergieron
# una vez (bug @buscar_predeterminadas, corregido en 4 sitios a la vez), así que ahora
# hay una sola definición y las dos la consumen.
#
# `detect` responde QUÉ fuente pide un texto; `available?` responde si esa fuente existe
# y está operativa para la cuenta/inbox. Nota: `available?` opera sobre la cadena de
# BÚSQUEDA (sin {{consulta:}}), igual que hacía kbase_available? antes de este cambio.
# ================================================================================

module KnowledgeBase
  module Directives
    module_function

    # @buscar_predefinidas(GRUPO)  -> solo las respuestas cuyo nombre empieza con GRUPO
    # @buscar_predefinidas(!GRUPO) -> todas MENOS esas
    # @buscar_predefinidas         -> todas (comportamiento historico)
    #
    # Existe para que dos ramas de un mismo agente puedan repartirse el corpus: la cuenta
    # tiene UNA sola fuente de respuestas predefinidas (indice unico
    # idx_unique_native_knowledge_sources), asi que separarlas en dos fuentes no es posible
    # y el reparto tiene que hacerse dentro. El grupo se compara contra el nombre de la
    # respuesta, que es lo que se vectoriza como titulo del knowledge_item.
    CANNED_RE = /@buscar_predefinidas\b(?:\s*\(([^)]*)\))?/i

    # Primera directiva de fuente presente en el texto → { mode:, source_name: } o nil.
    # El orden es precedencia: gana la primera que coincida.
    def detect(text)
      prompt = text.to_s
      return { mode: :erp_query } if ExternalDb::ConsultaDirectiveRenderer.contains?(prompt)

      detect_search(prompt)
    end

    # Igual que `detect` pero sin {{consulta:}} — solo las fuentes de búsqueda.
    def detect_search(text)
      prompt = text.to_s
      canned = canned_directive(prompt)
      return canned if canned

      if prompt.match?(/@buscar_art[ií]culo\b/i)
        { mode: :article }
      elsif (match = prompt.match(/@buscar_foro\(([^)]+)\)/i))
        { mode: :knowledge_source, source_name: match[1].strip }
      elsif (match = prompt.match(/\{\{doc:([^}]+)\}\}/i))
        { mode: :google_doc, source_name: match[1].strip }
      elsif (match = prompt.match(/\{\{hoja:([^}]+)\}\}/i))
        { mode: :google_sheet, source_name: match[1].strip }
      elsif prompt.match?(/@discourse\b/i)
        { mode: :discourse_integration }
      end
    end

    # El grupo es opcional: @buscar_predefinidas sin paréntesis sigue trayendo TODO, que es
    # lo que hacen los agentes que ya existen.
    def canned_directive(prompt)
      match = prompt.match(CANNED_RE)
      return nil if match.nil?

      { mode: :canned_response, group: match[1]&.strip.presence }
    end

    # ¿El texto pide una fuente que además existe y está operativa?
    def available?(text, account:, inbox_id:)
      ready?(detect_search(text), account: account, inbox_id: inbox_id)
    end

    # Misma pregunta, sobre una directiva ya detectada.
    def ready?(directive, account:, inbox_id:)
      return false if directive.blank? || account.blank?

      case directive[:mode]
      when :canned_response       then items?(account, 'canned_response')
      when :article               then items?(account, 'article')
      when :knowledge_source      then account.knowledge_sources.active.exists?(name: directive[:source_name])
      when :google_doc            then google_source?(account, 'google_doc', directive[:source_name])
      when :google_sheet          then google_source?(account, 'google_sheet', directive[:source_name])
      when :discourse_integration then discourse_hook?(account, inbox_id)
      else false
      end
    rescue StandardError
      false
    end

    def items?(account, source_type)
      account.knowledge_items.exists?(source_type: source_type)
    end

    # Las fuentes Google reutilizan la conexión de Google Calendar: sin esa feature,
    # {{doc:}} y {{hoja:}} no operan.
    def google_source?(account, source_type, name)
      account.feature_enabled?('google_calendar') &&
        account.knowledge_sources.active
               .exists?(['source_type = ? AND LOWER(name) = LOWER(?)', source_type, name.to_s])
    end

    def discourse_hook?(account, inbox_id)
      account.hooks.exists?(app_id: 'discourse', inbox_id: inbox_id, status: 'enabled')
    end
  end
end

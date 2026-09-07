# frozen_string_literal: true

# ================================================================================
# @tickets_cases (recursos por ID_RECURSO) — Emparejador de recursos del catálogo
# ================================================================================
# Servicio: Cases::Ai::ResourceMatcher
#
# Dada una lista de recursos que el cliente pidió en su propio lenguaje (ej. "Hiab
# 14 a 15 Ton con 5 extensiones"), los empareja contra las filas RECURSO reales del
# catálogo ({{hoja:...}} del Agente IA) que además tengan un calendario asignado
# (CALENDAR_ID). Nunca inventa un ID_RECURSO que no esté en el catálogo: si no
# encuentra un calce razonable, devuelve id_recurso: nil para esa solicitud (el
# caller decide si eso implica escalar).
#
# `find_by_name`/`match_by_requirements` (docs/vault-tickets Pendiente.md, plan
# @disponibilidad_recurso, 2026-09-04): resolución por nombre exacto o por requisitos
# técnicos (capacidad, izaje, dimensiones) para la nueva directiva de disponibilidad
# acotada — independiente de `match`, que resuelve por texto libre vía LLM.
# ================================================================================

class Cases::Ai::ResourceMatcher < Cases::Ai::BaseService
  def initialize(account:, tracking:)
    super(account: account)
    @tracking = tracking
  end

  # requested_descriptions: array de strings (una por recurso pedido).
  # Devuelve un array en el MISMO orden: [{ requested:, id_recurso:, calendar_id:, name: }]
  def match(requested_descriptions)
    descriptions = Array(requested_descriptions).map { |d| d.to_s.strip }.reject(&:blank?)
    return [] if descriptions.blank?

    resources = catalog_resources
    return descriptions.map { |d| unmatched(d) } if resources.blank?

    raw = chat(system: system_prompt(resources), user: user_prompt(descriptions), json: true, max_tokens: 400)
    build_results(descriptions, resources, raw)
  end

  # Coincidencia EXACTA por ID_RECURSO o NOMBRE (sin LLM) — ej. el cliente escribió
  # "REC-001" o "TP-94" tal cual. nil si no hay coincidencia exacta: el caller decide
  # si cae a `match_by_requirements` con lo que ya sepa del pedido.
  def find_by_name(nombre)
    needle = nombre.to_s.strip
    return nil if needle.blank?

    found = catalog_resources.find do |r|
      r[:id_recurso].to_s.casecmp?(needle) || r[:nombre].to_s.casecmp?(needle)
    end
    found && resource_result(found)
  end

  # requirements: { peso_toneladas:, necesita_izaje: (true/false/nil), largo_m:, ancho_m: }.
  # Cualquier clave ausente/nil no se evalúa. Un recurso sin el dato en el catálogo para
  # una clave SÍ pedida se descarta (información insuficiente, no se asume que cumple).
  # Devuelve TODOS los que califican — el caller decide qué hacer con 0/1/varios.
  def match_by_requirements(requirements)
    reqs = requirements || {}
    catalog_resources.select { |r| meets_requirements?(r, reqs) }.map { |r| resource_result(r) }
  end

  # Recurso real detrás de un CALENDAR_ID ya confirmado (ej. después de agendar vía
  # @disponibilidad_calendar) — para que el ticket, creado DESPUÉS de la cita (Fase 3),
  # sepa qué unidad quedó ligada. nil si ese calendario no corresponde a ningún RECURSO.
  def find_by_calendar_id(calendar_id)
    needle = calendar_id.to_s.strip
    return nil if needle.blank?

    found = catalog_resources.find { |r| r[:calendar_id].to_s == needle }
    found && resource_result(found)
  end

  # Punto de entrada de @disponibilidad_calendar: dado el texto del cliente (+ contexto
  # reciente), determina si nombra un recurso o da requisitos técnicos, y resuelve contra
  # el catálogo real. Nombre no encontrado → cae a requisitos para recomendar similares
  # (2026-09-04, decisión del usuario), nunca un callejón sin salida silencioso.
  # Devuelve { applicable:, resources:, resolved_by: :name|:requirements|:requirements_fallback,
  #            requested_name: }. `applicable: false` = el mensaje no pide disponibilidad
  # (ni nombró recurso ni dio requisitos) — el caller no debe tomar el turno.
  def resolve_for_availability(message_text, recent_context: '')
    extracted = extract_request(message_text, recent_context)
    name = extracted['resource_name'].to_s.strip.presence
    reqs = symbolize_requirements(extracted['requirements'])
    return { applicable: false } if name.blank? && reqs.blank?

    if name.present?
      found = find_by_name(name)
      return { applicable: true, resources: [found], resolved_by: :name, requested_name: name } if found

      # Nombre no encontrado y sin ningún requisito para intentar una recomendación: mostrar
      # el pool completo acá sería el mismo bug que esta directiva existe para evitar.
      return { applicable: true, resources: [], resolved_by: :requirements_fallback, requested_name: name } if reqs.blank?

      return { applicable: true, resources: match_by_requirements(reqs), resolved_by: :requirements_fallback,
               requested_name: name }
    end

    { applicable: true, resources: match_by_requirements(reqs), resolved_by: :requirements, requested_name: nil }
  end

  private

  def extract_request(message_text, recent_context)
    raw = chat(system: extraction_system_prompt, user: extraction_user_prompt(message_text, recent_context),
               json: true, max_tokens: 200)
    raw.is_a?(Hash) ? raw : {}
  rescue StandardError => e
    Rails.logger.warn "[ResourceMatcher] ⚠️ extract_request falló: #{e.message}"
    {}
  end

  def extraction_system_prompt
    <<~PROMPT.strip
      Analizas un mensaje para saber si el cliente pide disponibilidad de un recurso/unidad
      ESPECÍFICO por su nombre o código (ej. "REC-001", "TP-94"), o si en cambio describe
      requisitos técnicos sin nombrar ninguno (peso, si necesita izar, medidas).
      Responde EXCLUSIVAMENTE con JSON:
      { "resource_name": "código tal cual lo escribió el cliente, o null si no nombró ninguno",
        "requirements": { "peso_toneladas": número o null, "necesita_izaje": true/false/null,
                           "largo_m": número o null, "ancho_m": número o null,
                           "carga_a_granel": true/false/null } }
      "carga_a_granel": true SOLO si el cliente describe expresamente material suelto/a granel
      (arena, grava, escombro, tierra) que se carga sin contenedor ni forma fija — false o null en
      cualquier otro caso (equipo, maquinaria, tanques, piezas rígidas, o si no quedó claro).
      No inventes valores que el cliente no haya dado — usá null para lo que no se mencionó.
      Si el mensaje no tiene relación con pedir disponibilidad de una unidad (ni nombre ni
      requisitos), dejá "resource_name" en null y todos los campos de "requirements" en null.
    PROMPT
  end

  def extraction_user_prompt(message_text, recent_context)
    <<~PROMPT.strip
      Contexto reciente de la conversación:
      #{recent_context.presence || '(sin contexto previo)'}

      Mensaje del cliente:
      "#{message_text}"
    PROMPT
  end

  def symbolize_requirements(raw)
    raw = {} unless raw.is_a?(Hash)
    { peso_toneladas: raw['peso_toneladas'], necesita_izaje: raw['necesita_izaje'],
      largo_m: raw['largo_m'], ancho_m: raw['ancho_m'], carga_a_granel: raw['carga_a_granel'] }.compact
  end

  def resource_result(resource)
    { id_recurso: resource[:id_recurso], calendar_id: resource[:calendar_id], name: resource[:nombre] }
  end

  # Remolques descritos para material A GRANEL (góndola/caja de volteo: arena, grava, escombro
  # suelto) no sirven para cargar equipo rígido (compresores, tanques, maquinaria) — aunque
  # numéricamente "cumplan" capacidad/largo/ancho (conv. #111 y #132: TP-117 se ofreció mal para
  # un compresor y un tanque). Sin un campo estructurado en el catálogo para esto, se detecta por
  # palabras clave en la DESCRIPCION — se excluye SIEMPRE que el pedido no sea explícitamente a
  # granel (ante duda, no se ofrece: mismo criterio que el resto de `meets_requirements?`).
  GRANEL_KEYWORDS = /g[oó]ndola|volteo|granel/i

  def meets_requirements?(resource, reqs)
    return false if reqs[:peso_toneladas].present? && !meets_capacity?(resource, reqs[:peso_toneladas])
    return false if reqs[:necesita_izaje] == true && resource[:puede_izar] != true
    return false if reqs[:largo_m].present? && !meets_dimension?(resource[:largo_m], reqs[:largo_m])
    return false if reqs[:ancho_m].present? && !meets_dimension?(resource[:ancho_m], reqs[:ancho_m])
    return false if bulk_only?(resource) && reqs[:carga_a_granel] != true

    true
  end

  def bulk_only?(resource)
    resource[:descripcion].to_s.match?(GRANEL_KEYWORDS)
  end

  def meets_capacity?(resource, peso_toneladas)
    resource[:capacidad_max_t].present? && resource[:capacidad_max_t] >= peso_toneladas.to_f
  end

  def meets_dimension?(resource_value, required_value)
    resource_value.present? && resource_value >= required_value.to_f
  end

  def build_results(descriptions, resources, raw)
    matches = raw.is_a?(Hash) ? Array(raw['matches']) : []

    descriptions.map do |desc|
      found = matches.find { |m| m.is_a?(Hash) && m['requested'].to_s.strip == desc }
      resource = found && resources.find { |r| r[:id_recurso] == found['id_recurso'].to_s.strip }
      resource ? matched(desc, resource) : unmatched(desc)
    end
  end

  def matched(desc, resource)
    { requested: desc, id_recurso: resource[:id_recurso], calendar_id: resource[:calendar_id], name: resource[:nombre] }
  end

  def unmatched(desc)
    { requested: desc, id_recurso: nil, calendar_id: nil, name: nil }
  end

  # Solo filas RECURSO con calendario asignado — sin CALENDAR_ID no hay nada que
  # agendar de forma aislada, así que no tiene sentido ofrecerlas como candidato.
  def catalog_resources
    source = knowledge_source
    return [] unless source

    GoogleSheetRow.where(knowledge_source_id: source.id)
                  .where("data->>'TIPO_REGISTRO' = 'RECURSO'")
                  .where("data->>'CALENDAR_ID' IS NOT NULL AND data->>'CALENDAR_ID' <> ''")
                  .filter_map do |row|
      id_recurso = row.data['ID_RECURSO'].to_s.strip
      next if id_recurso.blank?

      { id_recurso: id_recurso, nombre: row.data['NOMBRE'], descripcion: row.data['DESCRIPCION'],
        calendar_id: row.data['CALENDAR_ID'], capacidad_max_t: numeric(row.data['CAPACIDAD_MAX_T']),
        puede_izar: si_no(row.data['PUEDE_IZAR']), largo_m: numeric(row.data['LARGO_M']),
        ancho_m: numeric(row.data['ANCHO_M']), tipo_recurso: row.data['TIPO_RECURSO'] }
    end
  end

  def numeric(value)
    str = value.to_s.strip
    return nil if str.blank?

    Float(str, exception: false)
  end

  # nil si el catálogo no trae "SI"/"NO" explícito — un valor desconocido nunca debe
  # contar como "sí cumple" (ver `meets_requirements?`: solo pasa con `true` exacto).
  def si_no(value)
    case value.to_s.strip.upcase
    when 'SI', 'SÍ' then true
    when 'NO' then false
    end
  end

  # El catálogo se resuelve por la MISMA directiva {{hoja:nombre}} que ya usa el
  # Agente IA para consulta técnica — no hace falta configurarlo aparte.
  def knowledge_source
    prompt = @tracking&.complementary_prompt.to_s
    m = prompt.match(/\{\{hoja:([^}]+)\}\}/i)
    return nil unless m

    @account.knowledge_sources.active.where(source_type: 'google_sheet')
            .where('LOWER(name) = LOWER(?)', m[1].strip).first
  end

  def system_prompt(resources)
    listado = resources.map { |r| "#{r[:id_recurso]}: #{r[:nombre]} — #{r[:descripcion]}" }.join("\n")
    <<~PROMPT.strip
      Tienes esta lista de recursos reales de un catálogo (ID_RECURSO: nombre — descripción):
      #{listado}

      Te van a dar una lista de recursos que pidió un cliente, en su propio lenguaje. Para
      cada uno, indica cuál ID_RECURSO de la lista de arriba le corresponde, o null si
      ninguno calza con confianza razonable. NO inventes un ID_RECURSO que no esté en la
      lista de arriba.
      Responde EXCLUSIVAMENTE con JSON:
      { "matches": [ { "requested": "texto pedido tal cual", "id_recurso": "ID o null" } ] }
    PROMPT
  end

  def user_prompt(descriptions)
    "RECURSOS PEDIDOS POR EL CLIENTE:\n#{descriptions.map { |d| "- #{d}" }.join("\n")}"
  end
end

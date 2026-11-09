# frozen_string_literal: true

# ================================================================================
# feat/ficha_agente_ia — LA FICHA CONTRA EL PROMPT
# ================================================================================
# Plan: docs/ficha_agente_ia_plan.md §8–§9. Pedido del usuario (09/11/2026): «si modifico
# la ficha se deben detectar esos cambios para el prompt y mencionarlo». Compara lo
# marcado en la ficha con lo que usan las rutas del Entrenamiento:
#
#   added    recursos marcados que ninguna ruta usa      → «tu agente ahora puede X: ¿agrego la ruta?»
#   removed  rutas que usan un recurso fuera de la ficha → «quitaste X y la usa la ruta Y»
#   not_ready recursos marcados que no están listos       → «PATITAS: 2 sin vectorizar»
#
# Y `deduced`: la ficha que se lee del prompt, para los agentes que ya existían (D2).
# Nada cambia el prompt aquí: solo se dice. Aplicar es PromptEditor, con el OK de la persona.
# ================================================================================

class ContactTrackings::Ficha::Changes
  LINE_RE = ContactTrackings::RouteMap::LINE_RE

  def initialize(template, cards: nil)
    @template = template
    @cards = cards || ContactTrackings::Ficha::Catalog.new(template.account, inbox: template.inbox, template: template).call
  end

  def call
    { added: added, removed: removed, not_ready: not_ready, deduced: deduced, confirmed: confirmed? }
  end

  def any? = added.any? || removed.any? || not_ready.any?

  # Lo que la ficha dice, o lo deducido del prompt si nunca se confirmó.
  def items
    guardados = Array(resources['items'])
    guardados.any? ? guardados : deduced
  end

  def confirmed? = resources['confirmed_at'].present?

  # Una línea por cambio, para el chat del Asistente (que lo mencione).
  def chat_lines
    return [] unless confirmed? && any?

    [
      'CAMBIOS EN LA FICHA DEL AGENTE (menciónalos al empezar y ofrece ajustar el Entrenamiento; no cambies nada sin su OK):',
      *added.map { |c| "- Agregó «#{c[:name]}»: ahora puede #{c[:label].downcase}. Ruta sugerida: #{c[:route][:line]}" },
      *removed.map { |c| "- Quitó «#{c[:name]}» de la ficha, pero la ruta #{c[:route]} todavía lo usa (#{c[:directive]})." },
      *not_ready.map { |c| "- «#{c[:name]}» no está listo: #{c[:warning]}." }
    ]
  end

  private

  def resources = (@template.resources || {}).with_indifferent_access

  def prompt = @template.complementary_prompt.to_s

  # [{ name:, target: }] de cada @ruta del texto.
  def routes
    @routes ||= prompt.lines.filter_map do |linea|
      m = linea.match(LINE_RE)
      { name: m[1], target: m[4].to_s } if m
    end
  end

  def all_offers
    @all_offers ||= ContactTrackings::Ficha::Offers.new(@cards, @cards.map { |c| { 'key' => c[:key] } }).call
  end

  def chosen_offers
    @chosen_offers ||= ContactTrackings::Ficha::Offers.new(@cards, items).call
  end

  def used?(oferta)
    return prompt.include?("{{#{oferta[:name]}}}") if oferta[:kind] == 'file'

    routes.any? { |r| uses?(r[:target], oferta) }
  end

  # loose: una búsqueda de predefinidas SIN grupo cubre todos los grupos (para «agregaste»);
  # para «quitaste» cuenta solo lo escrito tal cual.
  def uses?(target, oferta, loose: true)
    directiva = oferta[:directive].to_s
    case oferta[:kind]
    when 'sheet' then sheet_match?(target, oferta[:name])
    when 'calendar' then target.match?(/@agendar_calendar\b/i)
    when 'case_type' then target.downcase.include?(directiva.downcase.delete_suffix(')'))
    when 'canned' then canned_used?(target, directiva, loose)
    when 'erp' then target.downcase.include?(directiva[/consulta:[^()}]+/].to_s.downcase)
    else target.downcase.include?(directiva.downcase)
    end
  end

  def bare_canned? = routes.any? { |r| canned_match?(r[:target], '@buscar_predefinidas') }

  def canned_used?(target, directiva, loose)
    canned_match?(target, directiva) || (loose && canned_match?(target, '@buscar_predefinidas'))
  end

  # {{hoja:Precios}} o {{hoja_buscar: Precios | …}}: las dos usan la hoja.
  def sheet_match?(target, nombre)
    target.match?(/\{\{\s*hoja(?:_buscar)?\s*:\s*#{Regexp.escape(nombre.to_s)}\s*[|}]/i)
  end

  # @buscar_predefinidas(PATITAS) contra lo escrito, sin importar mayúsculas ni espacios.
  def canned_match?(target, directiva)
    grupo = directiva[/\(([^)]*)\)/, 1].to_s.strip.downcase
    escrito = target.scan(/@buscar_predefinidas\b(?:\s*\(([^)]*)\))?/i).map { |g| g.first.to_s.strip.downcase }
    escrito.include?(grupo)
  end

  def added
    @added ||= chosen_offers.reject { |o| used?(o) }.map { |o| o.slice(:key, :kind, :name, :label, :route, :directive) }
  end

  # Rutas que usan un recurso conocido de la cuenta que NO está en la ficha.
  def removed
    @removed ||= routes.flat_map { |ruta| removed_in(ruta) }.uniq { |c| [c[:key], c[:route]] }
  end

  def removed_in(ruta)
    return [] if covered?(ruta[:target])

    outside_offers.select { |o| uses?(ruta[:target], o, loose: false) }
                  .map { |o| { key: o[:key], name: o[:name], route: ruta[:name], directive: o[:directive] } }
  end

  # Las ofertas de la cuenta que NO están en la ficha (los archivos no son rutas).
  def outside_offers
    @outside_offers ||= begin
      elegidas = chosen_offers.pluck(:key)
      all_offers.reject { |o| elegidas.include?(o[:key]) || o[:kind] == 'file' }
    end
  end

  # La ruta ya usa algo que sí está en la ficha con la misma directiva (p. ej. dos agendas).
  def covered?(target)
    chosen_offers.any? { |o| o[:kind] == 'calendar' && uses?(target, o) }
  end

  def not_ready
    chosen_offers.select { |o| o[:status] == 'warn' || o[:warning].present? }
                 .map { |o| { key: o[:key], name: o[:name], warning: o[:warning] || 'no está listo' } }
  end

  # La ficha que se lee del prompt: cada recurso que alguna ruta (o {{archivo}}) usa.
  def deduced
    @deduced ||= begin
      usados = all_offers.select { |o| used?(o) }
      por_tarjeta = usados.group_by { |o| card_key(o) }
      with_assigned_calendars(por_tarjeta.map { |key, ofertas| deduced_item(key, ofertas) })
    end
  end

  # Las ofertas de predefinidas son por grupo (canned_response:PATITAS); la tarjeta es una.
  def card_key(oferta) = oferta[:key].to_s.start_with?('canned_response') ? 'canned_response' : oferta[:key]

  def deduced_item(key, ofertas)
    return { 'key' => key } unless key == 'canned_response'

    partes = ofertas.filter_map { |o| o[:key].to_s.split(':', 2)[1] }
    # Una búsqueda sin grupo = todas las predefinidas (sin elegir grupos).
    return { 'key' => key } if partes.include?('*') || partes.empty? || bare_canned?

    { 'key' => key, 'parts' => partes }
  end

  # La agenda: las que el agente YA tiene asignadas, no la primera de la cuenta. Solo si
  # alguna ruta agenda: tener calendarios asignados sin usarlos no es «agenda» en la ficha.
  def with_assigned_calendars(lista)
    asignadas = Array(@template.calendar_integration_ids).map { |id| "calendar:#{id}" } & @cards.pluck(:key)
    return lista if asignadas.empty? || lista.none? { |i| i['key'].start_with?('calendar:') }

    lista.reject { |i| i['key'].start_with?('calendar:') } + asignadas.map { |k| { 'key' => k } }
  end
end

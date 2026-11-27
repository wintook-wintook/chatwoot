# frozen_string_literal: true

# ================================================================================
# proyecto@solicitudes — LO PEDIDO NO ESTÁ EN LA HOJA: LO MÁS PARECIDO (observación SSUSA 1)
# ================================================================================
# Lo usa Scheduler (salió de ahí el 27/11/2026, sin cambiar lo que ya hacía). Si la hoja no tiene
# el equipo pedido («hiab», «grúa»), se busca otra vez sin los filtros de texto y con los de números
# («peso_max_t>=?»): las unidades que aguantan la carga, ofrecidas como «lo más parecido».
#
# 27/11/2026 (pruebas con la guía de SSUSA, conv. 204):
#   · esa segunda búsqueda usa el PESO de la carga, no la capacidad del equipo que no está
#   · si lo más parecido tampoco tiene horario, la nota dice que no se tiene ese equipo
# ================================================================================

module ContactTrackings::ServiceRequests::RelatedUnits
  private

  # ── Observación SSUSA 1: lo pedido no está en la hoja ────────────────────────
  # Se busca otra vez sin los filtros de texto («tipo=?») y con los de números («peso_max_t>=?»):
  # las unidades que aguantan lo pedido, ofrecidas como «lo más parecido».
  def related_spec
    filtros = @spec.filters.reject { |filtro| filtro.ask? && !filtro.numeric? }
    return nil if filtros.empty? || filtros.size == @spec.filters.size

    ContactTrackings::SheetLookup::Spec.new(sheet: @spec.sheet, filters: filtros, returns: @spec.returns)
  end

  def related_note(datos)
    tipo = datos['equipment_type'].presence
    tipo ? "no tengo #{tipo}; lo más parecido que tengo:" : 'estas unidades aguantan la carga:'
  end

  # 27/11/2026 (conv. 204): sin horario en lo más parecido, el bloque decía solo «a las 11:00 no
  # hay, ni más tarde ese día», como si el equipo pedido existiera y estuviera ocupado.
  def mark_related(plan, datos)
    plan.related = related_note(datos)
    return if plan.offers.present? || plan.need_time || datos['equipment_type'].blank?

    plan.note = ["no tengo #{datos['equipment_type']}", plan.note].compact_blank.join('; y lo más parecido: ')
  end

  def lookup_with_fallback(datos)
    partes = [datos['equipment_type'], datos['capacity_t'] && "#{datos['capacity_t']} t", datos['weight_t'] && "#{datos['weight_t']} t"]
    texto = partes.compact.join(' ')
    @related = false
    resultado = ContactTrackings::SheetLookup.new(@tracking.account, @spec, text: texto).call
    # Sin capacidad ni peso no hay con qué comparar: «lo más parecido» serían todas.
    return resultado if resultado.ok? || related_spec.nil? || (datos['capacity_t'].blank? && datos['weight_t'].blank?)

    @related = true
    ContactTrackings::SheetLookup.new(@tracking.account, related_spec, text: related_text(datos, texto)).call
  end

  # Lo más parecido se busca con el PESO de la carga: la capacidad era la del equipo pedido, que
  # no está en la hoja (27/11/2026, conv. 204: «grúa de 50 t» para un bote de 9 t buscaba
  # remolques de 50 t o más, porque de dos números se toma el mayor). Sin peso, como antes.
  def related_text(datos, texto)
    datos['weight_t'].present? ? "#{datos['weight_t']} t" : texto
  end
end

# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — LO QUE SE LE DEVUELVE AL MODELO PARA CORREGIR
# ================================================================================
# Los tres diagnósticos que vuelven al mismo hilo: gramática (comprobador), ruteo
# (RouteSelfCheck) y edición (DraftDiff). Viven juntos porque comparten la regla que
# los hace servir: nombran lo CONCRETO —el carácter, la rama, la sección—, nunca un
# veredicto. Medido el 08/09/2026: con un veredicto pelado se reparaba 1 de 3 veces;
# nombrando lo que falta, 3 de 3.
#
# Los textos están en config/locales/tracking_assistant.*.yml, en el idioma de la
# cuenta: los hallazgos ya vienen traducidos, y un prompt mezclado confunde.
# ================================================================================

module ContactTrackings::Assistant::RepairPrompts
  module_function

  # Los mensajes del comprobador van TEXTUALES. Reescribirlos "para que se entiendan
  # mejor" es justo lo que los vuelve inútiles.
  def grammar(blocking)
    detalle = blocking.map do |finding|
      linea = finding[:wrote].present? ? "\n  #{t('repair.wrote')} #{finding[:wrote]}" : ''
      "- #{finding[:message]}#{linea}"
    end

    wrap('repair.header', detalle, 'repair.footer')
  end

  def routing(cruces)
    detalle = cruces.map do |c|
      t('repair.route_mismatch_line', route: c.route, probe: c.probe, chosen: chosen(c))
    end

    wrap('repair.route_header', detalle, 'repair.route_footer')
  end

  def edit(cambios)
    wrap('repair.edit_header', cambios.map { |c| t("repair.edit_#{c.kind}", key: c.key) }, 'repair.edit_footer')
  end

  # Un cruce que sobrevive a la corrección, como hallazgo degradante.
  def route_finding(cruce)
    { code: :route_not_self_chosen,
      message: t('findings.route_not_self_chosen', route: cruce.route, probe: cruce.probe, chosen: chosen(cruce)),
      wrote: cruce.probe }
  end

  def chosen(cruce)
    cruce.chosen || t('repair.route_none')
  end

  def wrap(header, detalle, footer)
    "#{t(header)}\n#{detalle.join("\n")}\n\n#{t(footer)}"
  end

  def t(key, **args)
    I18n.t("tracking_assistant.#{key}", locale: ContactTrackings::Assistant::Language.resolve, **args)
  end
end

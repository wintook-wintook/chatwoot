# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — CÓMO SE EDITA UN ENTRENAMIENTO QUE YA EXISTE
# ================================================================================
# La parte del prompt del sistema que solo va cuando hay un Entrenamiento en
# pantalla (fase A de PROMPT STUDIO). Aparte de Instructions porque es otro modo de
# trabajo, con reglas que contradicen a propósito las de crear: al crear se entrevista
# por pasos y se escriben seis secciones; al editar no se entrevista y se conserva la
# estructura que haya.
# ================================================================================

class ContactTrackings::Assistant::EditingInstructions
  # El Entrenamiento que la persona tiene en pantalla, y lo que hay que hacer con él.
  #
  # ⚠ Hasta el 15/09/2026 esto no existía y el modelo nunca veía el Entrenamiento: un
  # pedido de cambio se resolvía reescribiendo de memoria, y un agente cargado para
  # arreglar se reemplazaba sin haberse leído. Las reglas de abajo salen de medirlo
  # sobre el v6.11: con "copiá todo lo demás carácter por carácter" una regla nueva
  # volvió con 1 línea distinta de 198.
  #
  # "No reorganices a las seis secciones" va explícito porque el contrato las exige
  # al CREAR, y sin esta aclaración esa exigencia se lee también al editar: un prompt
  # escrito a mano, con sus propias secciones, se normalizaría en silencio.
  # building: lo que está en pantalla es un BORRADOR de la entrevista (tiene marcas
  # <PENDIENTE:>), no un Entrenamiento terminado. Ahí las reglas de editar no aplican:
  # la entrevista sigue, y cada respuesta completa marcas.
  def self.call(current_draft, manual: [], building: false)
    principal = building ? building_section(current_draft) : body(current_draft)
    [principal, manual_section(manual)].compact.join("\n\n")
  end

  # Fase C: el borrador que se va armando a la vista.
  def self.building_section(current_draft)
    <<~CONSTRUCCION.strip
      ═══ EL BORRADOR QUE ESTÁS ARMANDO ═══
      Abajo está el borrador tal como lo ve la persona ahora, con lo que haya cambiado a mano.
      La entrevista SIGUE: no la des por terminada porque ya haya un borrador.

      Con la respuesta de este turno, devolvelo completo reemplazando las <PENDIENTE:> que ya
      se puedan completar. Todo lo demás va copiado igual, incluido lo que la persona escribió
      a mano. Lo que siga sin contestar, sigue marcado.

      ENTRENAMIENTO ACTUAL:
      <<<ENTRENAMIENTO
      #{current_draft}
      ENTRENAMIENTO>>>
    CONSTRUCCION
  end

  # Fase B: las piezas que la persona escribió a mano desde la última entrega. Se
  # nombran porque "respetá las ediciones a mano" en general no le dice al modelo
  # CUÁLES son: para él todo el texto es igual de actual.
  def self.manual_section(manual)
    return nil if manual.blank?

    <<~MANUAL.strip
      ═══ LA PERSONA EDITÓ ESTO A MANO ═══
      Desde tu última entrega, la persona cambió con sus propias manos: #{manual.join('  ')}
      Esas piezas NO se tocan salvo que el mensaje lo pida explícitamente. Si igual las
      cambiás, se le devuelve su versión y la tuya queda como opción aparte.
    MANUAL
  end

  def self.body(current_draft)
    <<~EDICION.strip
      ═══ ESTÁS EDITANDO UN ENTRENAMIENTO QUE YA EXISTE ═══
      Abajo está el ENTRENAMIENTO ACTUAL: lo que la persona tiene en pantalla ahora, con los
      cambios que haya hecho a mano. Es la fuente de verdad. No tu recuerdo de la conversación.

      SI EL MENSAJE PIDE UN CAMBIO
        Devolvé el Entrenamiento COMPLETO con SOLO ese cambio. Todo lo demás va copiado
        carácter por carácter: las ramas, las secciones, el orden, las mayúsculas, hasta los
        errores de tipeo. No "mejores" nada que no te hayan pedido.

        NO lo reorganices a las seis secciones del contrato: esa forma es para CREAR. Si tiene
        otras secciones ([NO SIMULAR], [GESTION EN CURSO], lo que sea), se quedan como están.
        Una sección que no entendés se conserva; nunca se borra.

        Lo que agregues o cambies sí respeta la gramática del contrato: la forma de @ruta, las
        fuentes del inventario, las frases del cliente en las descripciones.

        LOS PASOS DE LA ENTREVISTA SON PARA CREAR, NO PARA EDITAR. Acá no se recorren: si el
        pedido trae lo necesario, se aplica en este mismo turno. Para una rama nueva lo
        necesario es solo esto: frases del cliente, fuente (o "-") y etiqueta. El escalamiento
        es OPCIONAL: si no lo mencionan, la rama va sin flecha, sin preguntar. Nunca vuelvas a
        preguntar algo que el pedido ya dice ni algo que valga para las demás ramas: esas ya
        están escritas.

        Solo si falta una de esas tres cosas, preguntá POR ESA, con "entrenamiento" en null.

      SI EL MENSAJE ES UNA PREGUNTA sobre el Entrenamiento y no un cambio, contestala con
      "entrenamiento" en null.

      AL ENTREGAR UNA EDICIÓN agregá dos llaves al JSON:
        "toca":    cada pieza que cambiaste, escrita EXACTAMENTE así:
                   "@ruta(nombre)"   "@ruta_por_defecto"   "[RÓTULO DE LA SECCIÓN]"
        "cambios": renglones cortos para la persona, uno por cambio:
                   "+ Se agregó la rama facturacion"   "~ [ESTILO]: sin emojis"   "- Se quitó [HORARIO]"
      Tu texto se compara línea por línea con el actual: lo que cambies y no nombres en "toca"
      te lo voy a devolver. Si agregar una rama te obliga a sumar su etiqueta en [ETIQUETAS],
      nombrá las dos.

      Al editar, "modo" no hace falta. "propuesta" va en null salvo que pidan cambiar el nombre
      o el objetivo del agente.

      ENTRENAMIENTO ACTUAL:
      <<<ENTRENAMIENTO
      #{current_draft}
      ENTRENAMIENTO>>>
    EDICION
  end
end

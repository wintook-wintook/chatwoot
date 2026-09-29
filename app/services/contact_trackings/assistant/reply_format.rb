# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — QUÉ DEVUELVE EL ASISTENTE EN CADA TURNO DE ENTREVISTA
# ================================================================================
# La forma del JSON y lo que va dentro, aparte de CÓMO se entrevista (Instructions):
# el formato lo lee el código —InterviewService, ReplyParser, TurnOutcome— y cambiarlo
# obliga a cambiar a esos tres, no a la entrevista.
#
# Fase C de PROMPT STUDIO: el Entrenamiento se arma a la vista. Medido el 15/09/2026:
# devolver el borrador parcial en cada turno suma 1–2 s (3,5–5,1 s → 5,3–6,4 s) y
# ~300 tokens de salida. Y sin reglas, el borrador de prueba adivinó etiquetas y
# escalamientos que nadie había elegido, y copió los rótulos ═══ del contrato
# adentro del Entrenamiento: de ahí las reglas de marcas.
# ================================================================================

class ContactTrackings::Assistant::ReplyFormat
  def self.interview
    <<~FORMATO.strip
      ═══ LO QUE ACOMPAÑA AL ENTRENAMIENTO ═══
      Al entregar, propón también los datos del agente, en "propuesta":
        nombre    corto y descriptivo, del tema que atiende. No repitas uno que ya exista.
        objetivo  una frase con para qué está el agente. Sale de lo que te pidieron.
        contexto  ⚠ SOLO datos del negocio que la persona te haya dicho EN ESTA CONVERSACIÓN
                  (horarios, versiones, políticas). Si no te dijo ninguno, va en "" y lo
                  aclaras en el mensaje.
                  NO inventes nada acá. Tú conoces las fuentes y los tipos de caso de la
                  cuenta; NO conoces sus precios, sus horarios ni sus políticas. Este campo
                  entra al prompt como "BASE DE CONOCIMIENTO" y el agente lo va a citar como
                  si fuera cierto: rellenarlo de memoria es hacerle decir cosas falsas.

      ═══ EL ENTRENAMIENTO SE ARMA A LA VISTA ═══
      La persona ve el Entrenamiento al lado del chat. Así que desde que sabes QUÉ RUTAS hay,
      cada turno devuelve también el borrador, con todo lo que ya sabes y NADA MÁS:

        Lo que todavía no te contestaron NO se adivina, se marca:
          descripción sin frases del cliente  →  @ruta(soporte: <PENDIENTE: frases del cliente>)
          fuente sin elegir                   →  ): <PENDIENTE: fuente>
          etiqueta sin elegir                 →  la ruta va sin #etiqueta (no admite marca)
          escalamiento sin decidir            →  la ruta va sin flecha
          ruta por defecto sin decidir        →  no escribas la línea @ruta_por_defecto
          algo de la prosa que no sabes       →  <PENDIENTE: qué falta> en su sección

        ⚠ NO escribas #etiqueta, flecha -> ni @ruta_por_defecto hasta que la persona los haya
        elegido, AUNQUE TE PAREZCAN OBVIOS. Un borrador con etiquetas o tipos de caso que nadie
        eligió se lee como decisiones tomadas, y la persona no vuelve a revisarlos. Una marca, o
        un hueco, se lee como lo que es: una pregunta abierta.

        Con cada respuesta, reemplaza las marcas que ya se pueden completar y copia igual todo
        lo demás. La etiqueta que elija la persona se escribe EN LA LÍNEA @ruta de su ruta
        (@ruta(soporte #demo: ...)): esa es la que usa el motor. Si hay una sección [ETIQUETAS],
        solo repite lo mismo; escribirla ahí y no en la línea @ruta no cambia nada. Los rótulos ═══ son de estas instrucciones: NUNCA van dentro del
        Entrenamiento.

      ═══ CÓMO RESPONDES ═══
      SIEMPRE un JSON con estas llaves:
        {"mensaje": "lo que le dices a la persona",
         "opciones": [{"pregunta": "¿Con qué etiqueta cierra?",
                       "elecciones": ["#demo", "#tracking", "otra"]}] | null,
         "modo": "responde" | "deriva" | null,
         "entrenamiento": "el borrador (o el Entrenamiento terminado), o null si todavía no sabes qué rutas hay",
         "completo": true | false,
         "propuesta": {"nombre": "...", "objetivo": "...", "contexto": "..."} | null}

      Mientras entrevistas: "opciones" con lo que preguntaste, "entrenamiento" con el borrador
      y sus marcas, "completo": false.
      Cuando terminas: "opciones" en null, "completo": true, el Entrenamiento SIN ninguna
      marca <PENDIENTE:> (con sus líneas @ruta y su prosa, sin explicaciones alrededor),
      "modo" con la respuesta del paso 1, y "propuesta" con los datos del agente.

      En "elecciones" va el VALOR que se va a usar, no la letra: "#demo", no "a". La letra la
      pone la pantalla. Las preguntas abiertas —"qué temas atiende", y todas las del paso 2— NO van en
      "opciones": no hay lista que ofrecer y un botón ahí sobra. Van numeradas en el mensaje.
    FORMATO
  end
end

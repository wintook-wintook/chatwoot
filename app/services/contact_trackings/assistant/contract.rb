# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — EL CONTRATO DEL MOTOR
# ================================================================================
# La mitad FIJA del meta-prompt: la gramática que el motor parsea, dictada al
# modelo que va a escribir el Entrenamiento.
#
# EL META-PROMPT SON DOS MITADES:
#   · esta, fija — la gramática, las reglas duras y los límites del motor.
#   · el inventario, generada en cada sesión por InventoryService — los nombres
#     reales de la cuenta. Esa NUNCA se escribe a mano.
#
# POR QUÉ VIVE JUNTO AL PARSER:
#   Si alguien cambia LINE_RE y no toca este texto, el asistente empieza a dictar
#   una gramática muerta y a producir Entrenamientos inválidos — sin que nadie se
#   entere, porque el motor es fail-soft. El spec de este archivo compara lo
#   dictado contra las constantes REALES (RouteMap, Directives, TicketCreator) y
#   falla si divergen. Mismo patrón que engine_config_spec contra apps.yml.
#
#   Por eso el catálogo de fuentes NO está escrito acá: lo arma InventoryService
#   desde KnowledgeSource::SOURCE_TYPES. Agregar una fuente al motor no obliga a
#   tocar este archivo.
# ================================================================================

class ContactTrackings::Assistant::Contract
  # Se dictan como texto porque el modelo necesita la FORMA, no el patrón. El spec
  # verifica que cada ejemplo de acá lo parseen los patrones de verdad.
  ROUTE_EXAMPLE = '@ruta(soporte #soporte1: no puedo entrar, me da error, no abre el sistema): ' \
                  '@buscar_articulo -> @crear_ticket(tipo=Soporte, prioridad=media)'
  DEFAULT_EXAMPLE = '@ruta_por_defecto: soporte'

  def self.call = new.call

  def call
    <<~CONTRATO.strip
      Sos un especialista en configurar Agentes IA del motor de Seguimientos de Wintook.
      Escribís el campo "Entrenamiento" de un agente.

      NO es un prompt libre: parte del texto lo parsea el sistema con patrones exactos y solo se
      ejecuta lo que coincide literalmente. Lo que no coincide NO falla: deja de existir, en
      silencio, sin error ni aviso. Un Entrenamiento que se lee perfecto puede no ejecutar nada.

      ═══ ZONA 1 · líneas de configuración ═══
      Las lee el sistema. Ni el agente ni el cliente las ven.

        #{ROUTE_EXAMPLE}
        #{DEFAULT_EXAMPLE}

      Forma exacta: @ruta(<nombre> #<etiqueta>: <descripción>): <fuente> -> <escalamiento>

        · Los DOS PUNTOS después del paréntesis de cierre son obligatorios. Sin ellos la línea
          no existe para el motor y esa rama no se lee. Es el error más frecuente.
        · nombre: minúsculas, números, guion y guion bajo. Sin espacios ni acentos.
        · #etiqueta: minúsculas, números y guion bajo; mínimo 3 letras. Es lo que disparan las
          automatizaciones de la cuenta, así que solo se usan etiquetas que existan.
        · descripción: es LO ÚNICO que el sistema usa para decidir si un mensaje va a esta rama.
          Escribila como lista de situaciones, EN LAS PALABRAS DEL CLIENTE, no en lenguaje de
          manual. Si te dieron frases reales de clientes, salen de ahí.
        · fuente: UNA sola, del inventario que te pasan. O un guion "-" si la rama no consulta nada.
        · -> escalamiento: opcional. Solo admite @crear_ticket(tipo=..., prioridad=...).
          Corre si la fuente no resolvió el turno.

      ═══ ZONA 2 · la prosa ═══
      Es lo único que lee el modelo del agente. Seis secciones, en este orden:

        [ROL] · [ALCANCE POR RAMA] · [FIDELIDAD] · [ETIQUETAS] · [ESTILO] · [PROHIBIDO]

      ═══ REGLAS DURAS ═══
      1. Las directivas (@buscar_*, @discourse, {{doc:}}, {{hoja:}}, @soporte_contpaq) van
         ÚNICAMENTE dentro de las líneas @ruta. Una directiva suelta en la prosa BLANQUEA el
         Entrenamiento entero: el agente se queda sin ninguna instrucción.
      2. Una sola fuente por rama. Si ponés dos, el motor usa la primera y descarta la otra.
      3. Si UNA rama lleva flecha de escalamiento, las ramas SIN flecha dejan de abrir casos.
         O llevan flecha todas las que deban abrir caso, o ninguna.
      4. No inventes nombres. Toda fuente, tipo de caso y etiqueta sale del inventario que te
         pasan. Si necesitás algo que no está, escribilo como <PENDIENTE: ...> y avisalo al final.

      ═══ LO QUE EL MOTOR NO PUEDE HACER ═══
      No escribas reglas que prometan esto, porque no se van a cumplir:
        · Buscar en dos fuentes en el mismo turno ("si no está en el foro, mirá la hoja").
        · Que el agente decida a mitad de la respuesta consultar algo.
        · Escalar a otra cosa que no sea @crear_ticket.
        · Recordar lo que se dijo al principio de una conversación larga: la ventana es corta.
        · Mandar archivos adjuntos desde una rama que consulta una fuente.
    CONTRATO
  end
end

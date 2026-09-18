# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — EL INVENTARIO, DICHO AL MODELO
# ================================================================================
# Convierte el hash de InventoryService en la mitad GENERADA del meta-prompt.
#
# Es una pieza aparte porque son dos responsabilidades distintas: InventoryService
# consulta la cuenta (y su salida también alimenta la pantalla y los selectores del
# formulario); esto decide cómo se le dice al modelo. Cambiar la redacción del
# prompt no debería obligar a tocar las consultas.
#
# LA REGLA QUE GOBIERNA ESTE TEXTO:
#   Todo nombre que el modelo escriba tiene que salir de acá. Un nombre inventado
#   —una fuente que no existe, un tipo de caso que no existe— produce un
#   Entrenamiento que parsea perfecto y no encuentra nada nunca, porque el motor es
#   fail-soft. Por eso las listas van completas y explícitas, y por eso se dice qué
#   hacer cuando algo falta: <PENDIENTE: ...>, nunca inventarlo.
# ================================================================================

class ContactTrackings::Assistant::InventoryPrompt
  def self.call(inventory) = new(inventory).call

  def initialize(inventory)
    @inventory = inventory
  end

  def call
    return empty_account if @inventory[:empty]

    ['═══ INVENTARIO REAL DE ESTA CUENTA — no uses ningún nombre que no esté acá ═══',
     sources, groups, case_types, labels, phrases].compact.join("\n\n")
  end

  private

  def sources
    lineas = @inventory[:sources].map { |s| "  #{s[:directive].ljust(34)} #{s[:name]}" }
    return 'FUENTES DISPONIBLES: ninguna. Ninguna rama puede consultar nada; usá "-" como fuente.' if lineas.empty?

    # La directiva va literal porque es texto exacto: el motor la busca con un patrón.
    "FUENTES DISPONIBLES (escribí la directiva EXACTA de la izquierda, una por rama):\n#{lineas.join("\n")}"
  end

  # El grupo de @buscar_predefinidas(GRUPO) es el prefijo del nombre de la respuesta;
  # con grupo la búsqueda es más exigente, así que solo sirve si el prefijo existe.
  def groups
    return nil if @inventory[:canned_groups].blank?

    listado = @inventory[:canned_groups].map { |g| "#{g[:prefix]} (#{g[:count]})" }.join(' · ')
    "GRUPOS de Respuestas predefinidas, para @buscar_predefinidas(GRUPO): #{listado}"
  end

  def case_types
    return 'TIPOS DE CASO: ninguno creado. No uses @crear_ticket.' if @inventory[:case_types].blank?

    "TIPOS DE CASO válidos para @crear_ticket(tipo=…): #{@inventory[:case_types].join(' · ')}"
  end

  def labels
    if @inventory[:labels].blank?
      return 'ETIQUETAS: la cuenta no tiene ninguna creada. Proponé la que corresponda y avisá al ' \
             'final con una línea "PENDIENTE: crear la etiqueta #x".'
    end

    "ETIQUETAS que existen en la cuenta: #{@inventory[:labels].join(' · ')}\n" \
      'Si hace falta una que no está, usala igual y avisá al final con "PENDIENTE: crear la etiqueta #x".'
  end

  # Lo más valioso del inventario para la calidad del ruteo: la descripción de cada
  # rama tiene que estar escrita con ESTAS palabras, no con las de un manual.
  def phrases
    return nil if @inventory[:customer_phrases].blank?

    "ASÍ ESCRIBEN LOS CLIENTES DE ESTA CUENTA (textual, con sus typos — usá estas palabras\n" \
      "en las descripciones de las ramas, no lenguaje de manual):\n" \
      "#{@inventory[:customer_phrases].map { |p| "  · #{p}" }.join("\n")}"
  end

  def empty_account
    <<~VACIO.strip
      ═══ INVENTARIO DE ESTA CUENTA ═══
      La cuenta todavía no tiene fuentes de conocimiento ni tipos de caso cargados.
      No entrevistes sobre el vacío: ofrecé un arquetipo, explicá qué haría falta cargar, y
      dejá TODO nombre propio como <PENDIENTE: ...>. No inventes ninguno.
    VACIO
  end
end

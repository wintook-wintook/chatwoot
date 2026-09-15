# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — ¿CADA RAMA SE ELIGE A SÍ MISMA?
# ================================================================================
# El comprobador dice si un Entrenamiento se EJECUTA. Esto dice si RUTEA, que es
# la pregunta que ningún parser puede contestar: tres ramas impecables pueden
# mandar todas las preguntas de soporte a la rama comercial y parsear perfecto.
#
# LA PRUEBA, Y POR QUÉ NO NECESITA INVENTAR PREGUNTAS:
#   La descripción de una rama YA ES una lista de situaciones en las palabras del
#   cliente —para eso existe, es lo único que el clasificador lee—. Así que la
#   prueba se escribe sola: se toma una frase de la descripción de cada rama y se
#   le pregunta al clasificador REAL a qué rama la manda.
#
#   Si la descripción de 'comercial' no rutea a 'comercial', esa descripción no
#   sirve: o es ambigua, o se la come otra rama. Es una contradicción interna del
#   Entrenamiento, comprobable sin conocer el negocio.
#
#   Salió de una corrida real del Asistente: escribió "a como esta el dolar hoy"
#   dentro de la descripción de la rama comercial, teniendo una rama
#   fuera_de_alcance. Con esta comprobación, ese Entrenamiento no pasa.
#
# LO QUE CUESTA:
#   Una llamada de clasificación por rama, la misma que paga el motor en cada
#   turno (60 tokens de salida, temperatura 0.1). NO vectoriza ni busca en
#   ninguna fuente: acá solo importa a qué rama cae, no qué encuentra después.
#   Por eso no reusa DryRunService, que además ejecuta la búsqueda.
#
#   Con una sola rama no se corre: no hay con qué cruzarse, y el clasificador
#   devuelve esa rama sin preguntarle al modelo.
# ================================================================================

class ContactTrackings::Assistant::RouteSelfCheck
  # Tope de ramas a probar. Más que esto no es un Entrenamiento, es un catálogo, y
  # el costo crece lineal.
  MAX_PROBES = 8
  # De la descripción se toma la primera situación, no toda la lista: la lista
  # entera menciona varios temas y probaría el clasificador contra un mensaje que
  # ningún cliente escribiría.
  MAX_PROBE_CHARS = 120
  # ⚠ Una situación de una sola palabra no es un mensaje de cliente. La rama soporte
  # del v6.11 empieza "usar, configurar, dar de alta…": probada con "usar" a secas,
  # gpt-4o-mini —el modelo que se usa cuando no hay canal, que en el Asistente es
  # siempre— no eligió ninguna rama 3 de 3 veces, y la pantalla mostraba un cruce
  # que no existía. Con "usar, configurar" eligió soporte 3 de 3 (medido 15/09/2026).
  MIN_PROBE_WORDS = 3

  Mismatch = Struct.new(:route, :probe, :chosen, keyword_init: true)

  def initialize(account, draft:, inbox: nil)
    @account = account
    @draft = draft.to_s
    @inbox = inbox
  end

  # Devuelve solo los CRUCES: [] significa que cada rama se eligió a sí misma.
  def call
    map = ContactTrackings::RouteMap.parse(@draft)
    return [] if map.routes.size < 2

    map.routes.first(MAX_PROBES).filter_map do |route|
      probe = probe_for(route)
      # Una descripción marcada como pendiente todavía no es algo que probar.
      next if probe.blank? || ContactTrackings::Assistant::PendingMarkers.pending?(probe)

      chosen = classify(map, probe)
      next if chosen == route.name

      Mismatch.new(route: route.name, probe: probe, chosen: chosen)
    end
  end

  private

  # La primera situación de la descripción. Se corta en la coma o el punto y coma
  # porque la descripción es una lista: "no puedo entrar, me da error, no abre" son
  # tres mensajes distintos, y el cliente escribe uno.
  #
  # Si la primera es muy corta se le suman las siguientes hasta MIN_PROBE_WORDS.
  def probe_for(route)
    frase = []
    route.description.to_s.split(/[,;]/).map(&:strip).compact_blank.each do |situacion|
      frase << situacion
      break if frase.join(' ').split.size >= MIN_PROBE_WORDS
    end

    frase.join(', ').truncate(MAX_PROBE_CHARS).presence
  end

  # El clasificador REAL, el mismo que corre en producción. Si se reimplementara
  # acá, la comprobación diría algo distinto de lo que va a pasar.
  def classify(map, probe)
    ContactTrackings::BranchClassifierService.new(tracking_double, message_double(probe), map).classify&.name
  rescue StandardError => e
    Rails.logger.warn "[Asistente/AutoPrueba] no se pudo clasificar: #{e.message}"
    nil
  end

  # Objetos reales sin persistir, igual que en DryRunService: el borrador todavía
  # no es un agente y no hay conversación.
  def message_double(content)
    Message.new(account: @account, content: content, message_type: :incoming)
  end

  def tracking_double
    @tracking_double ||= ContactTracking.new(inbox: @inbox, complementary_prompt: @draft)
  end
end

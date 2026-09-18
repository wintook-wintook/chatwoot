# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — COMPROBAR CONTRA LO QUE LA CUENTA TIENE
# ================================================================================
# Las reglas que no miran la gramática del Entrenamiento sino si la cuenta puede
# sostener lo que ese Entrenamiento pide. Un texto puede ser impecable y apuntar a
# un corpus que no va a responder nunca.
#
# Va aparte de ValidatorService porque es otro tipo de pregunta: aquello mira la
# forma; esto mira el contenido de la cuenta.
# ================================================================================

class ContactTrackings::Assistant::CorpusChecks
  # ── grupo de predefinidas con corpus mínimo ─────────────────────────────────
  # Con grupo, el umbral de similitud sube de 0.20 a 0.45: la búsqueda se vuelve
  # mucho más exigente, a propósito. Sobre dos o tres respuestas eso significa que
  # la rama casi nunca va a encontrar nada.
  #
  # Salió de una corrida real: el asistente vio el grupo "DATOS" en el inventario y
  # se lo puso a una rama de actualizaciones de versión. El grupo tenía dos
  # respuestas, de datos fiscales y bancarios. La directiva es válida, el grupo
  # existe, y la rama no iba a responder nunca — nada lo marcaba.
  MIN_GROUP_SIZE = 4

  def initialize(map, account:, findings:)
    @map = map
    @account = account
    @findings = findings
  end

  def call
    check_canned_group_size
  end

  private

  attr_reader :findings

  def check_canned_group_size
    @map.routes.each do |route|
      group = narrowing_group(route)
      next if group.nil?

      total = canned_count_for(group)
      next if total >= MIN_GROUP_SIZE

      # El pluralizador de Rails es inglés y deja "2 respuesta": se arma a mano.
      cuantas = total == 1 ? '1 respuesta predefinida' : "#{total} respuestas predefinidas"

      findings.add(
        :degrading, :canned_group_too_small,
        "La rama '#{route.name}' busca en el grupo #{group}, que tiene #{cuantas}. Con grupo el " \
        'umbral de similitud sube de 0.20 a 0.45, así que sobre tan pocas respuestas la rama ' \
        'casi nunca va a encontrar nada. Conviene revisar que el grupo sea el correcto y que ' \
        'tenga contenido del tema de esta rama.',
        wrote: route.directive
      )
    end
  end

  # El grupo que ESTRECHA el corpus, o nil. Un grupo negado (!GESTION) lo amplía,
  # así que no cuenta para esta regla.
  def narrowing_group(route)
    return nil if route.directive.blank?

    group = KnowledgeBase::Directives.detect(route.directive)&.dig(:group)
    return nil if group.blank? || group.start_with?('!')

    group
  end

  # El grupo es el prefijo del short_code, que es lo que se vectoriza como título.
  def canned_count_for(group)
    @account.canned_responses.where('UPPER(short_code) LIKE ?', "#{group.upcase}%").count
  end
end

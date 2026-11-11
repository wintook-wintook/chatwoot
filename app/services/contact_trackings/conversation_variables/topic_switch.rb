# frozen_string_literal: true

# ================================================================================
# El cliente nombra otro valor de una variable de texto libre → el motor la cambia
# ================================================================================
# 11/11/2026 (cuenta 1128, conv 235): hablaban de Bienes Raíces, el cliente volvió a
# Psicología («¿Qué es lo que se ve en la licenciatura de psicología?») y después reclamó
# «ya me habías dado un descuento del 52%». La búsqueda trajo primero la ficha de
# Psicología, pero el modelo no había reescrito CARRERA: seguía en Bienes Raíces, y con
# ella contestó las becas, la titulación y todo lo demás. La regla del Entrenamiento
# («si el cliente vuelve a una carrera… CARRERA vuelve a esa carrera») ya estaba.
#
# Genérico, sin saber que la variable se llama CARRERA. Una variable de texto libre cuyo
# valor actual es el título de una respuesta predefinida («Licenciatura en Bienes
# Raíces…») tiene «hermanos»: las predefinidas de la misma categoría cuyo título empieza
# con la misma palabra («Licenciatura en Psicología», «Licenciatura en Derecho»…; no
# «Licenciaturas: formas de titulación»). Si el mensaje del cliente nombra a UNO solo de
# esos hermanos, la variable pasa a su título antes de buscar y de contestar.
#
# «Nombrar»: las palabras propias del título (sin las que están en más de la mitad de los
# hermanos, como «licenciatura») aparecen en el mensaje; con títulos de dos o más palabras
# propias hacen falta dos («trabajo social», no solo «social» de «servicio social»).
# Empate entre hermanos → no se cambia nada.
# ================================================================================

module ContactTrackings::ConversationVariables::TopicSwitch
  MIN_WORD = 4
  PREFIX = 6
  STOPWORDS = %w[para como sobre entre desde esta este tiene tienen quiero saber].freeze

  module_function

  # {NOMBRE => título nuevo}; {} si el mensaje no nombra otro valor.
  def changes_for(tracking, conversation, question, account_id)
    definition = ContactTrackings::ConversationVariables.definition_for(tracking)
    return {} if definition.blank? || conversation.nil?

    actuales = ContactTrackings::ConversationVariables.current(tracking, conversation, definition)
    stems = stems_of(question)
    definition.variables.each_with_object({}) do |(clave, var), out|
      valor = topic_value(var, actuales[clave])
      nuevo = valor && named_sibling(account_id, valor, stems)
      out[var[:name]] = nuevo if nuevo && key(nuevo) != key(valor)
    end
  end

  # El valor si es texto libre del cliente (no VACÍO ni otra opción declarada); nil si no.
  def topic_value(var, valor)
    valor = valor.to_s
    return nil unless var[:free] && valor.present?
    return nil if var[:options].any? { |opcion| key(opcion) == key(valor) }

    valor
  end

  def named_sibling(account_id, valor, stems)
    titles = CannedResponse.where(account_id: account_id).pluck(:short_code, :category_id)
    anchor = anchor_for(titles, valor)
    return nil if anchor.nil?

    frame = first_word(anchor[0])
    siblings = titles.select { |title, category| category == anchor[1] && first_word(title) == frame }.map(&:first).uniq
    return nil if siblings.size < 2

    best_named(siblings, stems)
  end

  # El título igual al valor o, si el modelo lo guardó corto («Licenciatura en Bienes
  # Raíces»), el único que contiene todas sus palabras.
  def anchor_for(titles, valor)
    exact = titles.find { |title, _| key(title) == key(valor) }
    return exact if exact

    wanted = stems_of(valor)
    candidates = titles.select { |title, _| wanted.present? && (wanted - stems_of(title)).empty? }
    candidates.one? ? candidates.first : nil
  end

  def best_named(siblings, stems)
    generic = common_stems(siblings)
    scored = siblings.filter_map { |title| named_score(title, generic, stems) }
    return nil if scored.empty?

    best = scored.map(&:last).max
    winners = scored.select { |_, hits| hits == best }
    winners.one? ? winners.first.first : nil
  end

  # [título, palabras propias nombradas] si el mensaje lo nombra; nil si no.
  def named_score(title, generic, stems)
    own = stems_of(title) - generic
    return nil if own.empty?

    hits = (own & stems).size
    [title, hits] if hits >= [2, own.size].min
  end

  def common_stems(titles)
    counts = titles.flat_map { |title| stems_of(title) }.tally
    counts.select { |_, n| n * 2 > titles.size }.keys
  end

  def stems_of(text)
    words = ActiveSupport::Inflector.transliterate(text.to_s.downcase).scan(/[a-z]+/)
    (words.select { |w| w.size >= MIN_WORD } - STOPWORDS).map { |w| w[0, PREFIX] }.uniq
  end

  def first_word(text)
    ActiveSupport::Inflector.transliterate(text.to_s.downcase)[/[a-z]+/]
  end

  def key(text)
    ContactTrackings::ConversationVariables.key(text)
  end
end

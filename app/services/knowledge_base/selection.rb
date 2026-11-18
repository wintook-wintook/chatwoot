# frozen_string_literal: true

# ================================================================================
# proyecto@predefinidas_que_contestan — BUSCAR Y ESCOGER (lo que ve el modelo)
# ================================================================================
# La búsqueda de respuestas predefinidas ya no deja que la similitud decida sola cuáles 3
# llegan. Ahora:
#
#   1. KnowledgeBase::Candidates  junta ~30 candidatas con tres redes: por palabras, por
#                                 similitud y exacta por el sujeto en curso (las fichas).
#   2. KnowledgeBase::Selector    una IA chica lee título, tipo, primera línea y el pedazo
#                                 donde coincidió, y escoge hasta 3 que SÍ contestan, o
#                                 ninguna.
#   3. Este módulo                arma lo que recibe el modelo: cada escogida con su marca
#                                 (DEL SUJETO / GENERAL / OBJECIÓN) y las reglas de uso.
#   4. KnowledgeBase::DataGuard   después de contestar: ningún monto, porcentaje ni código
#                                 que no venga de lo que vio.
#
# Por qué: medido en pruebas, la parte con las promociones no quedaba entre las 3 más
# parecidas y el agente inventaba una; dos fichas de sujetos distintos se parecían por
# 0.005 y ganaba la de otro. La similitud sirve para encontrar, no para decidir.
#
# Se activa por cuenta mientras se mide: custom_attributes.kbase_search.seleccion = true.
# Apagada, la búsqueda es la de siempre.
# ================================================================================
module KnowledgeBase::Selection
  FLAG = 'seleccion'

  # Las marcas con que cada escogida le llega al modelo.
  LABELS = {
    'ficha' => 'FICHA DE «%<subject>s»',
    'ficha_otro' => 'FICHA DE OTRO SUJETO: «%<subject>s»',
    'general' => 'GENERAL',
    'objecion' => 'OBJECIÓN DEL CLIENTE'
  }.freeze

  RULES = <<~RULES.strip
    CÓMO USAR LA INFORMACIÓN (regla dura):
    - Cada bloque trae su marca. Los datos de un sujeto (precio, promoción, código, liga, condiciones) salen SOLO de su
      FICHA. Lo marcado FICHA DE OTRO SUJETO no se usa para dar datos, salvo que el cliente pregunte por ese sujeto.
    - Lo GENERAL vale para todos. Si una FICHA y lo GENERAL se complementan, usa los dos; si se contradicen, para lo del
      sujeto manda la FICHA.
    - Lo marcado OBJECIÓN DEL CLIENTE dice cómo contestar ese pretexto: síguelo con tus palabras, sin copiarlo.
    - Si lo que pidió el cliente no está en ningún bloque, dilo como piden tus instrucciones para cuando no tienes el dato
      y ofrece lo que sí tienes; nunca lo completes ni lo calcules.
  RULES

  NONE_NOTE = <<~NOTE.strip
    Ninguna respuesta predefinida contesta lo que pidió el cliente%<missing>s.
    No inventes ni completes ese dato: dilo como piden tus instrucciones para cuando no tienes el dato.%<nearby>s
  NOTE

  module_function

  def enabled?(account)
    value = account&.custom_attributes&.dig('kbase_search', FLAG)
    ActiveModel::Type::Boolean.new.cast(value) || false
  end

  # La marca de una escogida, según su tipo y si es del sujeto en curso.
  def label(item, subjects)
    kind = item_kind(item)
    return LABELS['general'] if kind == 'general'
    return LABELS['objecion'] if kind == 'objecion'

    subject = subject_of(item.title)
    key = subjects.any? { |s| same_subject?(item.title, s) } || subjects.empty? ? 'ficha' : 'ficha_otro'
    format(LABELS[key], subject: subject)
  end

  # Lo que recibe el modelo cuando la IA no escogió ninguna.
  def none_context(missing, nearby_titles)
    faltante = missing.present? ? " (falta: #{missing})" : ''
    cercanas = if nearby_titles.any?
                 "\nLo más cercano que sí existe, por si le sirve al cliente (ofrécelo, no lo presentes como la respuesta): " \
                   "#{nearby_titles.first(3).join(' · ')}."
               else
                 ''
               end
    format(NONE_NOTE, missing: faltante, nearby: cercanas)
  end

  def item_kind(item)
    kind = item.metadata.to_h['kind'].to_s
    CannedResponse::KINDS.include?(kind) ? kind : 'general'
  end

  # El sujeto de una ficha es su nombre hasta « — », « - » o «:» («Plan Empresarial — Precio
  # y promociones» → «Plan Empresarial»).
  def subject_of(title)
    title.to_s.split(/\s+[—–-]\s+|:\s/).first.to_s.strip
  end

  # ¿La ficha es de ese sujeto? Por su nombre, sin acentos ni mayúsculas: el sujeto completo
  # o el valor dentro del nombre («Ciencias de la Educación» en «Licenciatura en Ciencias de
  # la Educación — Costos»).
  def same_subject?(title, value)
    sujeto = key(subject_of(title))
    valor = key(value)
    return false if sujeto.blank? || valor.blank?

    sujeto == valor || " #{sujeto} ".include?(" #{valor} ") || " #{valor} ".include?(" #{sujeto} ")
  end

  def key(text)
    I18n.transliterate(text.to_s).downcase.gsub(/[^a-z0-9]+/, ' ').squish
  end
end

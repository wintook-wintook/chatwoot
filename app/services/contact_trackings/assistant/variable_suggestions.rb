# frozen_string_literal: true

# ================================================================================
# proyecto@adaptar_prompts_publicados (F7) — ¿QUÉ DATOS DE ESTE PROMPT SON DE UN NEGOCIO?
# ================================================================================
# Un prompt pegado de otra cuenta (o el de uno mismo, antes de publicarlo) trae datos de
# una empresa concreta: su nombre, teléfonos, horario, dirección. El modelo los señala y
# la pestaña «Configurar» ofrece convertirlos en <PENDIENTE: nombre> — con el mismo
# reemplazo protegido que al publicar (PublishedPrompts::Variables): nunca dentro de una
# directiva, de una línea @ruta ni de otra marca.
#
# El modelo solo PROPONE. Se descarta lo que no aparece tal cual en la prosa (lo que
# inventó o copió mal) y lo que no tiene forma de variable. No se escribe nada: convertir
# es otro pedido, con lo que la persona eligió.
# ================================================================================

class ContactTrackings::Assistant::VariableSuggestions
  MAX = 15
  MAX_CHARS = 30_000
  LABEL_MAX = 60

  SYSTEM = <<~PROMPT
    Lees el Entrenamiento de un agente de atención al cliente. Señala los DATOS DE UN NEGOCIO
    CONCRETO que otra empresa tendría que cambiar para usar este mismo Entrenamiento: nombre de
    la empresa o de la marca, teléfonos, correos, direcciones, horarios, sitios web, nombres de
    personas del equipo, ciudades o zonas que atiende, precios o cuentas bancarias.

    No señales: directivas (lo que va entre {{ }} o empieza con @), etiquetas con #, reglas
    generales de cómo atender, ni palabras comunes del giro («grúas», «colegiatura»).

    Copia cada texto EXACTAMENTE como aparece (mismas mayúsculas, acentos y espacios). Dale un
    nombre corto, en español, de lo que es («Nombre del negocio», «Teléfono», «Horario»).

    Responde solo JSON: {"variables": [{"text": "...", "label": "..."}]}. Si no hay ninguno:
    {"variables": []}
  PROMPT

  Result = Struct.new(:variables, :error, keyword_init: true)

  def initialize(text, account:)
    @text = text.to_s
    @account = account
  end

  def call
    return Result.new(variables: []) if @text.blank?

    chat = ContactTrackings::Assistant::OpenaiChat.new(account: @account)
    return Result.new(variables: [], error: 'no_api_key') if chat.api_key.blank?

    datos = chat.call([{ role: 'system', content: SYSTEM }, { role: 'user', content: @text.first(MAX_CHARS) }])
    return Result.new(variables: [], error: 'failed') if datos.nil?

    Result.new(variables: candidates(datos['variables']))
  end

  private

  # Solo lo que de verdad está en la prosa, con cuántas veces aparece.
  def candidates(lista)
    PublishedPrompts::Variables.normalize(lista).filter_map do |variable|
      label = variable['label'].delete('<>').truncate(LABEL_MAX).presence || variable['text'].truncate(LABEL_MAX)
      count = PublishedPrompts::Variables.count(@text, variable['text'])
      next if count.zero? || !PublishedPrompts::Variables::TEXT_LENGTH.cover?(variable['text'].size)

      { 'text' => variable['text'], 'label' => label, 'count' => count }
    end.first(MAX)
  end
end

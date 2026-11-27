# frozen_string_literal: true

# Motor 2.0 — la bienvenida de la empresa combinada con la primera respuesta (agentes de una función). Va tal cual al
# inicio; si el modelo la repite se quita; un «¡Hola, Mario!» de más se quita; y queda una sola pregunta: la de la
# bienvenida si el cliente solo saludó, o la de la respuesta si ya pidió algo. Lo incluye Motor2::Runner.
module Motor2::WelcomeCombine
  private

  # La bienvenida de la empresa va tal cual al inicio del primer mensaje (la pone el código).
  def welcome_note
    return nil unless @welcome

    "Tu mensaje lo empieza la bienvenida de la empresa (la pone el código): «#{@welcome}». No saludes ni te presentes " \
      'otra vez: escribe solo lo que sigue (contesta lo que preguntó, si preguntó algo, y la pregunta pendiente).'
  end

  def with_welcome(text)
    return text unless @welcome

    @trace.event(:bienvenida, 'combinada con la respuesta')
    attach_welcome_files
    # Si el modelo la volvió a escribir (pasa aunque se le diga, a veces con otros espacios o
    # signos), se quita: va una sola vez.
    rest = text.to_s.gsub(welcome_pattern, '').strip.sub(/\A[\s.,;:!?]+/, '')
    rest = '' if greeting_only?(rest) # «¡Hola!» o «¡Hola, Mario!» después de la bienvenida sobra
    welcome = welcome_part(rest)
    rest = rest_part(rest)
    [welcome, (rest unless greeting_only?(rest))].compact_blank.join("\n\n")
  end

  # Una sola pregunta: si solo saludó, la de la bienvenida («¿Qué se te antoja hoy?»); si ya pidió algo («quiero un
  # corte»), la de la respuesta («¿Para dama o caballero?») y la bienvenida va sin la suya.
  def welcome_part(rest)
    return @welcome unless welcome_asks? && !only_greeted? && rest.include?('?')

    without_questions(@welcome).presence || @welcome
  end

  def rest_part(rest) = welcome_asks? && only_greeted? ? without_questions(rest) : rest

  def only_greeted? = ContactTrackings::WelcomeMessage.only_greeting?(@last_customer)

  # Solo un saludo, aunque traiga su nombre («¡Hola Mario!», «¡Qué gusto, Mario!»): hasta 4 palabras sin pregunta que
  # empiezan con un saludo.
  def greeting_only?(text)
    return true if ContactTrackings::WelcomeMessage.only_greeting?(text)

    words = I18n.transliterate(text.to_s.downcase).scan(/[a-z]+/)
    return false if words.empty? || words.size > 4 || text.match?(/[?\d]/)

    words.size <= 2 || %w[hola buenas buenos buen que mucho bienvenido bienvenida].include?(words.first)
  end

  # Los archivos marcados «con la bienvenida» van con ella (también en «Probar»); Motor2::Reply los anota
  # como enviados, así no se repiten.
  def attach_welcome_files
    Motor2::Skills::Files.welcome_names(@config.template).each { |name| attach(name) }
  end

  # La bienvenida con cualquier espacio o signo entre sus palabras.
  def welcome_pattern
    words = @welcome.scan(/[[:alnum:]]+/).map { |w| Regexp.escape(w) }
    Regexp.new("[¿¡]?\\s*#{words.join('[^[:alnum:]]+')}[^[:alnum:]\\n¿¡]*", Regexp::IGNORECASE)
  end
end

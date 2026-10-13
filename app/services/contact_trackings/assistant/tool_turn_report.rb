# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — LO QUE CORRIÓ EN UN TURNO CON HERRAMIENTAS (P8)
# ================================================================================
# Lo arma el CÓDIGO con lo que de verdad corrió, no con lo que el modelo dice que hizo:
# medido en la línea base del P8 (T3), el Asistente decía «arreglado» sin haber probado.
#
#   steps    una línea por herramienta, EN VIVO mientras el turno corre (Paso 3.2):
#            «Probé 4 frases: todas estables ✓». Viaja con cada aviso de TurnProgress.
#   message  el mensaje final con formato fijo (Paso 3.1): lo que dijo el modelo (qué
#            hizo y por qué) + «Qué probé» (cada frase con su ruta y el comprobador) +
#            «Pendiente». Los cambios no se repiten: la pantalla ya los muestra.
#
# SOLO LO PROBADO SOBRE LA VERSIÓN ENTREGADA: el modelo prueba varias veces mientras
# corrige. Medido el 13/10/2026 (T1 con el prototipo): el reporte juntaba pruebas de
# borradores intermedios y mostraba «¿cuánto cuesta?» → crisis, cuando en lo entregado
# caía en informes 3 de 3. Lo probado sobre versiones anteriores se cuenta, no se lista.
#
# Textos en es/en: tracking_assistant.tools_report (config/locales).
# ================================================================================

class ContactTrackings::Assistant::ToolTurnReport
  MAX_STEPS = 8

  def initialize
    @probes = {}
    @check = nil
    @steps = []
  end

  # Cada herramienta que corrió (no las consultas repetidas: esas no corren).
  # texto: el Entrenamiento sobre el que corrió la prueba (AssistantTools#apply).
  def record(nombre, argumentos, resultado, texto: nil)
    datos = JSON.parse(resultado)
    remember(nombre, datos, texto)
    @steps << step_line(nombre, parse_args(argumentos), datos)
  rescue JSON::ParserError
    @steps << t('live.failed', tool: nombre)
  end

  def steps = @steps.last(MAX_STEPS)

  def message(mensaje, pendiente, final: nil)
    [mensaje.to_s.strip, tested(final), pending(pendiente)].compact_blank.join("\n\n")
  end

  private

  # Lo último de cada frase y del comprobador: si el modelo corrigió y volvió a probar,
  # vale la última prueba.
  # La prueba de ruteo vale para lo entregado si las RUTAS son las mismas (el clasificador
  # solo lee las líneas @ruta: el modelo las prueba solas, sin las secciones); el
  # comprobador, si el texto entero es el mismo.
  def remember(nombre, datos, texto)
    remember_probes(datos, routes_version(texto)) if nombre == 'probar_ruta'
    @check = datos.merge('version' => version(texto)) if nombre == 'comprobar' && datos.is_a?(Hash) && datos.key?('ejecuta')
  end

  # Por versión y frase: la misma frase sobre otra versión es otra prueba.
  def remember_probes(datos, version)
    Array(datos).each { |p| @probes[[version, p['frase']]] = p.merge('version' => version) if p.is_a?(Hash) && p['frase'] }
  end

  # Una huella del texto, sin espacios: para saber si lo probado es lo entregado.
  def version(texto)
    texto.nil? ? nil : Digest::SHA1.hexdigest(texto.to_s.gsub(/\s+/, ''))
  end

  def routes_version(texto)
    texto.nil? ? nil : version(texto.to_s.lines.grep(/\A\s*@ruta/).join)
  end

  def parse_args(argumentos)
    JSON.parse(argumentos.presence || '{}')
  rescue JSON::ParserError
    {}
  end

  # ── en vivo ─────────────────────────────────────────────────────────────────
  def step_line(nombre, args, datos)
    return t('live.failed', tool: nombre) if datos.is_a?(Hash) && datos['error']

    metodo = "live_#{nombre}"
    respond_to?(metodo, true) ? send(metodo, args, datos) : t('live.failed', tool: nombre)
  end

  def live_ver_recursos(_args, _datos) = t('live.resources')
  def live_ver_directiva(args, _datos) = t('live.directive', name: args['nombre'])
  def live_ver_hoja(_args, datos) = t('live.sheet', name: datos['nombre'])
  def live_comprobar(_args, datos) = check_line(datos, 'live.check_ok', 'live.check_blocking')
  def live_revisar_encargo(_args, datos) = brief_line(datos)
  def live_probar_ruta(_args, datos) = route_line(Array(datos))

  def check_line(datos, si_ejecuta, si_no)
    datos['ejecuta'] ? t(si_ejecuta) : t(si_no, count: Array(datos['bloqueantes']).size)
  end

  def brief_line(datos)
    faltan = Array(datos['faltan_reglas']).size + Array(datos['faltan_datos']).size
    faltan.zero? ? t('live.brief_ok') : t('live.brief_missing', count: faltan)
  end

  def route_line(frases)
    inestables = frases.count { |f| f['estable'] == false }
    return t('live.route_stable', total: frases.size) if inestables.zero?

    t('live.route_unstable', total: frases.size, unstable: inestables)
  end

  # ── el mensaje final ────────────────────────────────────────────────────────
  def tested(final)
    lineas = final_lines(final).presence || [t('nothing')]
    anteriores = @probes.values.count { |p| p['version'] != routes_version(final) }
    lineas << t('earlier', count: anteriores) if anteriores.positive?
    "**#{t('tested')}**\n#{lineas.map { |l| "- #{l}" }.join("\n")}"
  end

  # Lo probado sobre la versión entregada: cada frase y el comprobador.
  def final_lines(final)
    lineas = @probes.values.select { |p| p['version'] == routes_version(final) }.map { |p| probe_line(p) }
    lineas << check_line(@check, 'checker_ok', 'checker_blocking') if @check && @check['version'] == version(final)
    lineas
  end

  def probe_line(probe)
    datos = { phrase: probe['frase'], route: probe['cae_en'], times: probe['veces'] }
    return t('stable', **datos) unless probe['estable'] == false

    t('unstable', **datos, others: Array(probe['a_veces_en']).join(', '))
  end

  def pending(pendiente)
    lista = Array(pendiente).map(&:to_s).compact_blank
    return nil if lista.empty?

    "**#{t('pending')}**\n#{lista.map { |l| "- #{l}" }.join("\n")}"
  end

  def t(key, **args)
    I18n.t("tracking_assistant.tools_report.#{key}", locale: ContactTrackings::Assistant::Language.resolve, **args)
  end
end

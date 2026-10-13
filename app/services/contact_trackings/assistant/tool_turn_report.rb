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
  def record(nombre, argumentos, resultado)
    datos = JSON.parse(resultado)
    remember(nombre, datos)
    @steps << step_line(nombre, parse_args(argumentos), datos)
  rescue JSON::ParserError
    @steps << t('live.failed', tool: nombre)
  end

  def steps = @steps.last(MAX_STEPS)

  def message(mensaje, pendiente)
    [mensaje.to_s.strip, tested, pending(pendiente)].compact_blank.join("\n\n")
  end

  private

  # Lo último de cada frase y del comprobador: si el modelo corrigió y volvió a probar,
  # vale la última prueba.
  def remember(nombre, datos)
    remember_probes(datos) if nombre == 'probar_ruta'
    @check = datos if nombre == 'comprobar' && datos.is_a?(Hash) && datos.key?('ejecuta')
  end

  def remember_probes(datos)
    Array(datos).each { |p| @probes[p['frase']] = p if p.is_a?(Hash) && p['frase'] }
  end

  def parse_args(argumentos)
    JSON.parse(argumentos.presence || '{}')
  rescue JSON::ParserError
    {}
  end

  # ── en vivo ─────────────────────────────────────────────────────────────────
  def step_line(nombre, args, datos)
    return t('live.failed', tool: nombre) if datos.is_a?(Hash) && datos['error']

    case nombre
    when 'ver_recursos' then t('live.resources')
    when 'ver_directiva' then t('live.directive', name: args['nombre'])
    when 'ver_hoja' then t('live.sheet', name: datos['nombre'])
    when 'comprobar' then check_line(datos, 'live.check_ok', 'live.check_blocking')
    else route_line(Array(datos))
    end
  end

  def check_line(datos, si_ejecuta, si_no)
    datos['ejecuta'] ? t(si_ejecuta) : t(si_no, count: Array(datos['bloqueantes']).size)
  end

  def route_line(frases)
    inestables = frases.count { |f| f['estable'] == false }
    return t('live.route_stable', total: frases.size) if inestables.zero?

    t('live.route_unstable', total: frases.size, unstable: inestables)
  end

  # ── el mensaje final ────────────────────────────────────────────────────────
  def tested
    lineas = @probes.values.map { |p| probe_line(p) }
    lineas << check_line(@check, 'checker_ok', 'checker_blocking') if @check
    lineas = [t('nothing')] if lineas.empty?
    "**#{t('tested')}**\n#{lineas.map { |l| "- #{l}" }.join("\n")}"
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

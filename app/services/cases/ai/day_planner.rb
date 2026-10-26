# frozen_string_literal: true

# ================================================================================
# @tickets_cases — Plan-Bandeja-Prioridad F4: «Plan de mi día» con IA
# ================================================================================
# Servicio: Cases::Ai::DayPlanner
#
# Lee «Mi día» YA ORDENADO (el orden propio del agente y luego las sugeridas por
# puntaje, con sus motivos), la agenda de hoy y la duración estimada, y lo explica
# en texto: en qué bloque del día va cada tarea, por qué, y qué conviene dejar
# para mañana si no alcanza el tiempo. NO reordena (decisión 2026-10-21: el orden
# lo dan las reglas; la IA solo explica y sugiere). Los ids que devuelva la IA se
# filtran contra las tareas enviadas: nunca se propone una tarea ajena.
# Devuelve un Hash o nil ante cualquier fallo.
# ================================================================================

class Cases::Ai::DayPlanner < Cases::Ai::BaseService
  MAX_TASKS = 15

  # tasks:  [{ task:, score:, reasons:, planned: }] en el orden de «Mi día»
  # agenda: [CaseMeeting] de hoy · zone: zona horaria del agente (el servidor
  # corre en UTC; las horas se le muestran en la suya).
  def plan(user:, tasks:, agenda:, zone: Time.zone)
    tasks = tasks.first(MAX_TASKS)
    return nil if tasks.empty?

    @zone = zone
    raw = chat(system: system_prompt, user: user_prompt(user, tasks, agenda), json: true,
               temperature: 0.3, max_tokens: 900)
    return nil if raw.blank?

    sanitize(raw, tasks.map { |t| t[:task].id })
  end

  private

  def system_prompt
    <<~PROMPT.strip
      Eres el asistente de planeación de un consultor. Recibes sus tareas pendientes YA
      ORDENADAS por prioridad (las marcadas [MI ORDEN] las ordenó él; las demás, un puntaje
      de urgencia con sus motivos), sus reuniones de hoy y la hora actual.
      Arma su plan para lo que RESTA del día, en español, breve y práctico:
        - NO cambies el orden de las tareas: respétalo y explica por qué va así.
        - Acomoda las tareas en bloques alrededor de las reuniones (las reuniones son fijas).
        - Usa la duración estimada; si una tarea no tiene, supón 30 minutos.
        - Una jornada tiene ~8 h. Si no alcanza, propone qué dejar para mañana (las de
          menor prioridad, nunca una vencida urgente).
        - No inventes tareas, datos ni horarios que no estén.
      Responde EXCLUSIVAMENTE con un objeto JSON:
        {
          "intro": "1-2 frases: el enfoque del día",
          "steps": [{ "task_id": 12, "when": "9:00–10:00", "note": "por qué ahora, en una frase" }],
          "later": [{ "task_id": 30, "note": "por qué puede esperar" }],
          "warning": "riesgo importante del día o null"
        }
    PROMPT
  end

  def user_prompt(user, tasks, agenda)
    <<~PROMPT.strip
      CONSULTOR: #{user.name}
      HORA ACTUAL: #{local(Time.current, '%H:%M')}

      TAREAS (en orden):
      #{tasks.each_with_index.map { |t, i| task_line(t, i + 1) }.join("\n")}

      REUNIONES DE HOY:
      #{agenda.map { |m| meeting_line(m) }.join("\n").presence || '(ninguna)'}
    PROMPT
  end

  def task_line(item, position)
    task = item[:task]
    ticket = task.case_ticket
    parts = ["#{position}. [id #{task.id}]#{' [MI ORDEN]' if item[:planned]} #{task.title}"]
    parts << "caso #{ticket.folio} (#{ticket.case_type&.case_class || 'support'}): #{ticket.title}" if ticket
    parts << "vence #{local(task.due_at, '%d/%m %H:%M')}" if task.due_at
    parts << "duración #{task.estimated_minutes} min" if task.estimated_minutes
    parts << "puntaje #{item[:score]} (#{item[:reasons].pluck(:key).join(', ')})"
    parts.join(' · ')
  end

  def meeting_line(meeting)
    "- #{local(meeting.starts_at, '%H:%M')}–#{meeting.ends_at && local(meeting.ends_at, '%H:%M')} #{meeting.title}"
  end

  def local(time, format)
    time.in_time_zone(@zone).strftime(format)
  end

  # Solo ids de las tareas enviadas, sin repetir entre «steps» y «later».
  def sanitize(raw, ids)
    steps = clean_items(raw['steps'], ids, %w[when note])
    later = clean_items(raw['later'], ids - steps.pluck('task_id'), %w[note])
    { 'intro' => raw['intro'].to_s.strip, 'steps' => steps, 'later' => later,
      'warning' => raw['warning'].presence&.to_s&.strip }
  end

  def clean_items(list, ids, fields)
    items = Array(list).filter_map do |item|
      next unless item.is_a?(Hash)

      id = item['task_id'].to_i
      next unless ids.include?(id)

      fields.index_with { |f| item[f].to_s.strip }.merge('task_id' => id)
    end
    items.uniq { |item| item['task_id'] }
  end
end

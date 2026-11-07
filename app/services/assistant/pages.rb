# frozen_string_literal: true

# Asistente (Dali) — las pantallas que open_page puede abrir: destino → ruta dentro de
# la cuenta. Las de un registro revisan que el usuario lo pueda ver (t = Assistant::Tools).
# Las guías de uso (config/assistant/guides) solo pueden citar pantallas de aquí.
module Assistant::Pages
  MAP = {
    'case' => ->(t, id) { "tickets/#{id}" if id && t.cases.exists?(id) },
    'contact' => ->(t, id) { "contacts/#{id}" if id && t.contacts.exists?(id) },
    'organization' => ->(t, id) { "organizations/#{id}" if id && t.organizations.exists?(id) },
    'conversation' => ->(_t, id) { "conversations/#{id}" if id },
    'agenda' => ->(_t, _id) { 'tickets/tasks' },
    'my_day' => ->(_t, _id) { 'tickets/tasks' },
    'tasks' => ->(_t, _id) { 'tickets/tasks' },
    'cases' => ->(_t, _id) { 'tickets' },
    'budget' => ->(_t, _id) { 'tickets/budget' },
    'pipeline' => ->(_t, _id) { 'tickets/commercial/metrics' },
    # Pantallas que mencionan las guías de uso (Assistant::Guides).
    'opportunities' => ->(_t, _id) { 'tickets/commercial/board' },
    'quotes' => ->(_t, _id) { 'tickets/quotes' },
    'contact_funnel' => ->(_t, _id) { 'kanban' },
    'contacts' => ->(_t, _id) { 'contacts' },
    'organizations' => ->(_t, _id) { 'organizations' },
    'contracts' => ->(_t, _id) { 'contracts' },
    'conversations' => ->(_t, _id) { 'dashboard' },
    'calendar' => ->(_t, _id) { 'google-calendar' },
    'task_reports' => ->(_t, _id) { 'tickets/task-reports' },
    'my_summary' => ->(_t, _id) { 'start' },
    'reports' => ->(_t, _id) { 'reports' },
    'ai_agents' => ->(_t, _id) { 'tracking-dashboard/agents' },
    'trackings' => ->(_t, _id) { 'tracking-dashboard' },
    'campaigns' => ->(_t, _id) { 'tracking-dashboard/campaigns' },
    'events' => ->(_t, _id) { 'events' },
    'catalog' => ->(_t, _id) { 'tickets/catalog' },
    'settings' => ->(_t, _id) { 'settings' }
  }.freeze
end

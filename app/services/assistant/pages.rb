# frozen_string_literal: true

# Asistente (Dali) — las pantallas que puede abrir (open_page) y ligar en sus respuestas
# ([[clave]], ver Assistant::PageLinks): destino → ruta dentro de la cuenta.
# - Las de un registro (caso, contacto…) viven aquí y revisan que el usuario lo pueda ver
#   (t = Assistant::Tools).
# - Las del menú viven en config/assistant/pages.json, con su nombre tal como se ve en el
#   menú. La prueba sidebarItems/v2/pagesCoverage.spec.js revisa que estén todas.
# Las guías de uso (config/assistant/guides) solo pueden citar pantallas de aquí.
module Assistant::Pages
  FILE = Rails.root.join('config/assistant/pages.json')

  RECORDS = {
    'case' => ->(t, id) { "tickets/#{id}" if id && t.cases.exists?(id) },
    'contact' => ->(t, id) { "contacts/#{id}" if id && t.contacts.exists?(id) },
    'organization' => ->(t, id) { "organizations/#{id}" if id && t.organizations.exists?(id) },
    'conversation' => ->(_t, id) { "conversations/#{id}" if id }
  }.freeze

  SCREENS = JSON.parse(File.read(FILE)).fetch('pages').freeze

  MAP = RECORDS.merge(SCREENS.transform_values { |page| ->(_t, _id) { page['path'] } }).freeze

  # Nombre de la pantalla como en el menú («Ventas › Oportunidades»); nil si es de un registro.
  def self.label(key) = SCREENS.dig(key.to_s, 'label')
end

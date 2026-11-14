# frozen_string_literal: true

# Asistente (Dali) — las pantallas que menciona en su respuesta salen como liga.
# El modelo escribe la clave de Assistant::Pages entre dobles corchetes:
#   [[opportunities]]                     → con el nombre del menú («Ventas › Oportunidades»)
#   [[opportunities|el tablero]]          → con su propio texto
#   [[case:12|OPB-00012]]                 → un registro (revisa que el usuario lo pueda ver)
# y aquí se cambia por [[/app/accounts/1/tickets/commercial/board|Ventas › Oportunidades]],
# que AssistantChat.vue pinta como liga. Si la clave no existe o el registro no se puede
# ver, queda solo el texto (nunca una liga rota).
#
# Uso: Assistant::PageLinks.new(tools).call(content)
class Assistant::PageLinks
  MARKER = /\[\[([a-z_]+)(?::(\d+))?(?:\|([^\]|]{1,80}))?\]\]/

  def initialize(tools)
    @tools = tools
  end

  def call(content)
    return content if content.blank?

    content.gsub(MARKER) do
      key = Regexp.last_match(1)
      id = Regexp.last_match(2)&.to_i
      label = Regexp.last_match(3).presence&.strip || Assistant::Pages.label(key)
      path = @tools.page_path(key, id)
      if path && label.present?
        "[[#{path}|#{label}]]"
      else
        label.to_s
      end
    end
  end
end

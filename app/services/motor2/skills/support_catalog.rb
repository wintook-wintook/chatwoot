# frozen_string_literal: true

# «Atención a clientes» › Soporte — de qué sistema o módulo habla el cliente, con el catálogo de casos
# (Casos › Clasificación: Servicios afectados y Categorías) como marco de referencia: lo decide el
# clasificador (Motor2::Triage) y, si no lo dice, va el que eligió la empresa en el asistente
# (areas.support.default_service_id). El caso que se levanta sale con ese servicio y esa categoría.
# Lo usa Motor2::Skills::Areas (por Motor2::Skills::SupportFlow).
module Motor2::Skills::SupportCatalog
  def service_name = now['servicio'].presence || default_service&.name

  private

  # Lo que ve el clasificador.
  def case_catalog
    { services: config.account.case_services.where(active: true).order(:position).pluck(:name),
      categories: config.account.case_categories.where(active: true).order(:position).pluck(:name),
      default: default_service&.name }
  end

  def system_line
    said = now['servicio'].present?
    "DE QUÉ HABLA (equipo, producto, sistema o servicio): #{service_name}" \
      "#{' (no lo dijo: es el que suele usar o el que atiende la empresa, salvo que diga otro)' unless said}"
  end

  # El servicio afectado y la categoría del caso, si los hay.
  def case_classification
    service = service_name && config.account.case_services.find_by(name: service_name, active: true)
    category = now['categoria'].presence && config.account.case_categories.find_by(name: now['categoria'], active: true)
    { affected_service_id: service&.id, category_id: category&.id }.compact
  end

  IDENTIFY_FIRST = 'Todavía no: antes de levantar su caso pregúntale de qué empresa nos escribe (una sola pregunta) y guárdalo ' \
                   'con identificar_empresa; con su respuesta lo levantas.'

  # Lo que falta antes de levantar un caso: buscar la solución, darla si es exacta, saber de qué empresa es.
  def case_blocker
    return Motor2::Skills::AreaActions::SEARCH_FIRST if search_first?
    return Motor2::Skills::SupportFlow::SOLUTION_FIRST if solution_first?

    IDENTIFY_FIRST if now['severidad'] != 1 && @turn.find_skill('identity')&.must_ask?
  end

  # El sistema del cliente si no lo dice: el que más usa (por sus casos) o, si no, el que eligió la empresa.
  def default_service
    return @default_service if defined?(@default_service)

    id = function.area('support').to_h['default_service_id']
    @default_service = customer_service || (id && config.account.case_services.find_by(id: id, active: true))
  end

  def customer_service
    name = Motor2::CustomerContext.systems(@turn.conversation&.contact).first
    name && config.account.case_services.find_by(name: name, active: true)
  end
end

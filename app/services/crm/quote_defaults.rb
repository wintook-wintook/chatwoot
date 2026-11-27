# CrmZeus Q3.1 — valores por omisión de una cotización nueva (solo al abrir el alta; al guardar no
# se tocan, así el agente puede dejarlos vacíos). Como master2 (`quotations/form.js`):
# - Vigencia y entrega: hoy (FECHA_VECTO / FECHA_ENTREGA = new Date()).
# - Contacto: CRMZeus pone el último contacto de la organización (CONTACTO_CONTACTO_ULT_ID, que
#   actualizan actividades y proyectos) o el predeterminado. Wintook no tiene esos módulos ni marca
#   de predeterminado: se usa el de la última cotización de la organización (si sigue ligado) y, si
#   no hay, el único contacto que tenga.
# - Consignatario: CRMZeus pone el predeterminado (ES_DEFAULT); sin esa marca, el único que tenga.
#   Un prospecto no lleva consignatario.
class Crm::QuoteDefaults
  def initialize(quote)
    @quote = quote
    @organization = quote.organization
  end

  def apply
    today = Time.zone.today
    @quote.valid_until ||= today
    @quote.delivery_date ||= today
    apply_organization if @organization
    @quote
  end

  private

  def apply_organization
    @quote.contact_id ||= last_quote_contact_id || only(@organization.contact_links.pluck(:contact_id))
    @quote.shipping_address_id ||= only(@organization.consignees.pluck(:id)) unless @organization.prospect?
  end

  def last_quote_contact_id
    @organization.quotes.where(contact_id: @organization.contact_links.select(:contact_id))
                 .order(quote_date: :desc, id: :desc).pick(:contact_id)
  end

  def only(ids)
    ids.first if ids.one?
  end
end

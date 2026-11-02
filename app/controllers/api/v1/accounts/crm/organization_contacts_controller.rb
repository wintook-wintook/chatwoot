# CrmZeus C1 — contactos de Wintook ligados a una organización (crm_organization_contacts).
#
#   GET    /crm/organizations/:organization_id/contacts                 los ligados
#   GET    /crm/organizations/:organization_id/contacts/search?q=       contactos de Wintook para ligar
#   POST   /crm/organizations/:organization_id/contacts                 { contact_id }
#   DELETE /crm/organizations/:organization_id/contacts/:id             :id = contact_id; solo desliga
#
# Como en `organizations` de develop: se ven todos los contactos de la organización, pero solo
# se liga un contacto que el usuario puede ver (Clientes «solo lo suyo»). Un contacto que ya está
# en otra organización se rechaza nombrándola; hay que desligarlo primero.
class Api::V1::Accounts::Crm::OrganizationContactsController < Api::V1::Accounts::Crm::BaseController
  SEARCH_LIMIT = 20

  before_action :check_sales_write_access, except: %i[index search]
  before_action :set_organization

  def index
    render json: { contacts: @organization.contacts.order(:name, :id).map { |contact| contact_json(contact) } }
  end

  def search
    return render json: { contacts: [] } if params[:q].blank?

    like = "%#{Contact.sanitize_sql_like(params[:q].strip)}%"
    contacts = visible_contacts.resolved_contacts
                               .where('contacts.name ILIKE :q OR contacts.email ILIKE :q OR contacts.phone_number ILIKE :q', q: like)
                               .order(:name, :id).limit(SEARCH_LIMIT).to_a
    links = CrmOrganizationContact.where(contact_id: contacts.map(&:id)).includes(:organization).index_by(&:contact_id)
    render json: { contacts: contacts.map { |contact| contact_json(contact).merge(crm_organization: linked_to(links[contact.id])) } }
  end

  def create
    contact = visible_contacts.find_by(id: params[:contact_id])
    return render json: { message: 'Contacto no encontrado' }, status: :not_found unless contact

    link = @organization.contact_links.new(contact: contact)
    return render_errors(link) unless link.save

    render json: { contact: contact_json(contact) }, status: :created
  end

  def destroy
    @organization.contact_links.find_by!(contact_id: params[:id]).destroy!
    head :ok
  end

  private

  def set_organization
    @organization = Current.account.crm_organizations.find(params[:organization_id])
  end

  def visible_contacts
    access_grant.contacts(Current.account.contacts)
  end

  def contact_json(contact)
    contact.slice(:id, :name, :email, :phone_number).merge(thumbnail: contact.avatar_url)
  end

  # En la búsqueda: la organización de CrmZeus en la que ya está (o nil).
  def linked_to(link)
    link&.organization&.slice(:id, :trade_name)
  end
end

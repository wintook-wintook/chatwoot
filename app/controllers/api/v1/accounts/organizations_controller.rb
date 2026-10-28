# Plan-Organizaciones O1 — prospectos y clientes (empresas o público en general) con sus
# contactos ligados.
#
#   GET    /organizations                 ?q= &stage= &kind= &owner_id= &page=  (+ meta.counts por etapa)
#   GET    /organizations/:id             con sus contactos y la bitácora
#   POST   /organizations                 (contact_id) liga ese contacto al crearla
#   PATCH  /organizations/:id             DELETE /organizations/:id (los contactos quedan sin organización)
#   POST   /organizations/:id/change_stage    (stage) prospecto ↔ cliente
#   POST   /organizations/:id/add_contact     (contact_id)
#   POST   /organizations/:id/remove_contact  (contact_id)
#   GET    /organizations/:id/summary     oportunidades, casos, cotizaciones, contratos y equipos
#   GET    /organizations/suggestions     O4: agrupa los contactos sin organización (vista previa)
#   POST   /organizations/apply_suggestions  (groups) crea o liga lo confirmado
#   GET    /organizations/template        CSV con las columnas · POST /organizations/import (file)
#   GET    /organizations/metrics         O5: ?months= (Informes › Dashboard de clientes)
#
# Área Clientes. Con «solo lo suyo» se ven las que tiene a su cargo y las de sus contactos.
class Api::V1::Accounts::OrganizationsController < Api::V1::Accounts::BaseController
  require 'csv'

  PER_PAGE = 50
  FIELDS = %i[name kind tax_id website email_domain industry phone_number address owner_id notes].freeze

  before_action :set_organization, except: %i[index create suggestions apply_suggestions template import metrics]
  before_action :set_contact, only: %i[add_contact remove_contact]

  def index
    organizations = filtered.includes(:owner).ordered
    page = [params[:page].to_i, 1].max
    rows = organizations.offset((page - 1) * PER_PAGE).limit(PER_PAGE).to_a
    @contact_counts = Contact.where(organization_id: rows.map(&:id)).group(:organization_id).count
    render json: {
      organizations: rows.map { |org| organization_json(org) },
      meta: { count: organizations.count, page: page, per_page: PER_PAGE, counts: stage_counts }
    }
  end

  def show
    render_organization
  end

  def create
    contact = params[:contact_id].present? ? visible_contacts.find_by(id: params[:contact_id]) : nil
    return render_access_denied if params[:contact_id].present? && contact.nil?

    @organization = new_organization(contact)
    ActiveRecord::Base.transaction do
      @organization.save!
      contact&.update!(organization: @organization)
    end
    render json: { organization: organization_json(@organization, detail: true) }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_errors_message(errors_of(e.record))
  end

  def update
    @organization.update(organization_params) ? render_organization : render_errors_message(errors_of(@organization))
  end

  def destroy
    @organization.destroy!
    head :no_content
  end

  def suggestions
    render json: { suggestions: suggestions_service.call }
  end

  def apply_suggestions
    groups = params.permit(groups: [:name, :kind, :stage, :email_domain, :existing_organization_id, { contact_ids: [] }])
    render json: suggestions_service.apply(groups[:groups], Current.user)
  end

  def metrics
    render json: Organizations::Metrics.new(scope: scope, months: params[:months] || 6).as_json
  end

  def template
    send_data Organizations::CsvImport::COLUMNS.to_csv, filename: 'organizaciones.csv', type: 'text/csv'
  end

  def import
    return render_errors_message(I18n.t('organizations.import.no_file')) if params[:file].blank?

    rows = CSV.parse(params[:file].read.force_encoding('UTF-8').delete_prefix("\uFEFF"), headers: true)
    render json: Organizations::CsvImport.new(account: Current.account, contacts: visible_contacts, user: Current.user)
                                         .call(rows)
  rescue CSV::MalformedCSVError => e
    render_errors_message(e.message)
  end

  def summary
    render json: Organizations::Summary.new(organization: @organization, grant: access_grant).as_json
  end

  def change_stage
    return render_errors_message(I18n.t('organizations.errors.stage')) unless Organization.stages.key?(params[:stage].to_s)

    @organization.change_stage!(params[:stage], Current.user)
    render_organization
  end

  def add_contact
    @contact.update!(organization: @organization)
    render_organization
  end

  def remove_contact
    @contact.update!(organization: nil) if @contact.organization_id == @organization.id
    render_organization
  end

  private

  def suggestions_service
    Organizations::Suggestions.new(account: Current.account, contacts: visible_contacts)
  end

  # Desde un contacto toma su empresa escrita (o público en general con su nombre).
  def new_organization(contact)
    organization = if contact
                     Organization.build_for(contact, organization_params.to_h.symbolize_keys)
                   else
                     Current.account.organizations.new(organization_params)
                   end
    organization.stage = params[:stage] if Organization.stages.key?(params[:stage].to_s)
    organization
  end

  def visible_contacts
    access_grant.contacts(Current.account.contacts)
  end

  def scope
    organizations = Current.account.organizations
    return organizations if access_grant.admin? || !access_grant.own?(:clients)

    organizations.where(owner_id: Current.user.id)
                 .or(organizations.where(id: visible_contacts.where.not(organization_id: nil).select(:organization_id)))
  end

  def filtered_without_stage
    organizations = scope.search(params[:q])
    organizations = organizations.where(kind: params[:kind]) if Organization.kinds.key?(params[:kind].to_s)
    organizations = organizations.where(owner_id: params[:owner_id]) if params[:owner_id].present?
    organizations
  end

  def filtered
    organizations = filtered_without_stage
    Organization.stages.key?(params[:stage].to_s) ? organizations.where(stage: params[:stage]) : organizations
  end

  # Cuántas hay en cada etapa con los mismos filtros: las pestañas.
  def stage_counts
    counts = filtered_without_stage.group(:stage).count
    Organization.stages.keys.index_with { |stage| counts[stage] || 0 }.merge('all' => counts.values.sum)
  end

  def set_organization
    @organization = scope.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: I18n.t('organizations.errors.not_found') }, status: :not_found
  end

  def set_contact
    @contact = visible_contacts.find_by(id: params[:contact_id])
    render_access_denied unless @contact
  end

  def organization_params
    params.fetch(:organization, {}).permit(*FIELDS).tap do |permitted|
      attributes = params.dig(:organization, :custom_attributes)
      permitted[:custom_attributes] = attributes.permit!.to_h if attributes.respond_to?(:permit!)
    end
  end

  def render_organization
    render json: { organization: organization_json(@organization.reload, detail: true) }
  end

  def render_errors_message(message)
    render json: { error: message }, status: :unprocessable_entity
  end

  def errors_of(record)
    record.errors.full_messages.join(', ')
  end

  def organization_json(organization, detail: false)
    json = organization.slice(:id, :name, :stage, :kind, :tax_id, :website, :email_domain, :industry, :phone_number,
                              :address, :owner_id, :custom_attributes, :notes, :became_prospect_at, :became_customer_at,
                              :created_at)
    json[:owner] = organization.owner&.slice(:id, :name)
    json[:contacts_count] = @contact_counts ? @contact_counts[organization.id].to_i : organization.contacts.count
    return json unless detail

    json.merge(contacts: organization.contacts.order(:name).map { |c| c.slice(:id, :name, :email, :phone_number) },
               events: events_json(organization))
  end

  def events_json(organization)
    organization.events.includes(:user).order(created_at: :desc).limit(50).map do |event|
      event.slice(:id, :action, :data, :created_at).merge(user: event.user&.slice(:id, :name))
    end
  end
end

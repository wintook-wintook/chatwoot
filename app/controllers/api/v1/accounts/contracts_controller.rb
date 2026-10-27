# Plan-Contratos R1 — contratos (servicios recurrentes) de los clientes.
#
#   GET   /contracts               ?contact_id= | ?q= &state= &contract_type_id= &page=
#   POST  /contracts               PATCH /contracts/:id
#   POST  /contracts/:id/register_payment   el cobro del periodo avanza un periodo
#   POST  /contracts/:id/renew               un plazo más
#   POST  /contracts/:id/cancel  (reason)    POST /contracts/:id/reactivate
#   GET   /contracts/template      CSV con las columnas para importar
#   POST  /contracts/import        CSV (file)
#
# Lo ven Clientes o Ventas (con «solo lo suyo», los de sus contactos); lo cambian con
# «Todo» o «Solo lo suyo» en cualquiera de las dos.
class Api::V1::Accounts::ContractsController < Api::V1::Accounts::BaseController
  require 'csv'

  PER_PAGE = 50
  FIELDS = %i[contact_id contract_type_id catalog_item_id customer_asset_id assignee_id title quantity price currency
              every unit starts_on next_charge_on term_months auto_renew status notes].freeze

  before_action :check_read_access
  before_action :check_write_access, except: %i[index template]
  before_action :set_contract, only: %i[update register_payment renew cancel reactivate]

  def index
    contracts = filtered.includes(:contact, :contract_type, :assignee, :customer_asset).ordered
    page = [params[:page].to_i, 1].max
    render json: {
      contracts: contracts.offset((page - 1) * PER_PAGE).limit(PER_PAGE).map { |contract| contract_json(contract) },
      meta: { count: contracts.count, page: page, per_page: PER_PAGE, counts: state_counts }
    }
  end

  def create
    contract = Current.account.contracts.new(contract_params)
    return render_access_denied unless visible_contact?(contract.contact_id)

    contract.save ? render(json: { contract: contract_json(contract) }, status: :created) : render_errors(contract)
  end

  def update
    @contract.update(contract_params.except(:contact_id)) ? render_contract : render_errors(@contract)
  end

  def register_payment
    @contract.register_payment!
    render_contract
  end

  def renew
    return render_errors_message(I18n.t('contracts.errors.no_term')) unless @contract.renew!

    render_contract
  end

  def cancel
    @contract.cancel!(params[:reason])
    render_contract
  end

  def reactivate
    @contract.reactivate!
    render_contract
  end

  def template
    send_data Contracts::CsvImport::COLUMNS.to_csv, filename: 'contratos.csv', type: 'text/csv'
  end

  def import
    return render_errors_message(I18n.t('contracts.import.no_file')) if params[:file].blank?

    rows = CSV.parse(params[:file].read.force_encoding('UTF-8').delete_prefix('﻿'), headers: true)
    render json: Contracts::CsvImport.new(account: Current.account, contacts: visible_contacts).call(rows)
  rescue CSV::MalformedCSVError => e
    render_errors_message(e.message)
  end

  private

  def visible_contacts
    access_grant.contacts(Current.account.contacts)
  end

  def visible_contact?(contact_id)
    visible_contacts.exists?(id: contact_id)
  end

  def scope
    Current.account.contracts.where(contact_id: visible_contacts.select(:id))
  end

  def filtered
    filtered_without_state.in_state(params[:state])
  end

  def search(contracts, term)
    like = "%#{ActiveRecord::Base.sanitize_sql_like(term.to_s.strip)}%"
    contracts.joins(:contact).where('contracts.title ILIKE :q OR contacts.name ILIKE :q OR contacts.email ILIKE :q ' \
                                    'OR contacts.phone_number ILIKE :q', q: like)
  end

  # Cuántos hay en cada estado (con los mismos filtros, sin el de estado): las pestañas.
  def state_counts
    base = filtered_without_state
    Contract::STATES.index_with { |state| base.in_state(state).count }
  end

  def filtered_without_state
    contracts = scope
    contracts = contracts.where(contact_id: params[:contact_id]) if params[:contact_id].present?
    contracts = contracts.where(contract_type_id: params[:contract_type_id]) if params[:contract_type_id].present?
    params[:q].present? ? search(contracts, params[:q]) : contracts
  end

  def set_contract
    @contract = scope.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: I18n.t('contracts.errors.not_found') }, status: :not_found
  end

  def contract_params
    permitted = params.require(:contract).permit(*FIELDS)
    attributes = params[:contract][:custom_attributes]
    permitted[:custom_attributes] = attributes.permit!.to_h if attributes.respond_to?(:permit!)
    amounts_visible? ? permitted : permitted.except(:price)
  end

  # Sin «Ver montos» el contrato se ve y se cambia, pero sin el precio.
  def amounts_visible?
    access_grant.can?(:see_amounts)
  end

  def check_read_access
    render_access_denied unless access_grant.allowed?(:clients) || access_grant.allowed?(:sales)
  end

  def check_write_access
    render_access_denied unless access_grant.writable?(:clients) || access_grant.writable?(:sales)
  end

  def render_contract
    render json: { contract: contract_json(@contract.reload) }
  end

  def render_errors(record)
    render_errors_message(record.errors.full_messages.join(', '))
  end

  def render_errors_message(message)
    render json: { error: message }, status: :unprocessable_entity
  end

  def contract_json(contract)
    contract.slice(:id, :contact_id, :contract_type_id, :catalog_item_id, :customer_asset_id, :assignee_id, :title,
                   :currency, :every, :unit, :starts_on, :next_charge_on, :last_paid_on, :term_months, :ends_on,
                   :auto_renew, :status, :cancelled_on, :cancel_reason, :custom_attributes, :notes)
            .merge(quantity: contract.quantity.to_f, price: (contract.price.to_f if amounts_visible?),
                   amount: (contract.amount.to_f if amounts_visible?), state: contract.state, links: links_json(contract))
  end

  def links_json(contract)
    {
      contact: contract.contact&.slice(:id, :name, :email, :phone_number),
      contract_type: contract.contract_type&.slice(:id, :name, :color),
      assignee: contract.assignee&.slice(:id, :name),
      customer_asset: contract.customer_asset&.slice(:id, :name)
    }
  end
end

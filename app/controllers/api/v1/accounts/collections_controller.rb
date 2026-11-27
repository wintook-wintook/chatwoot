# frozen_string_literal: true

# Cobranza — la pantalla «Cobranza» (solo administradores: son saldos de clientes).
#   GET  collections/overview                tablero (Receivables::Overview) + agentes de cobranza
#   GET  collections/template                la plantilla del Excel (CSV)
#   POST collections/preview                 { file, mapping } → encabezados, columnas reconocidas y qué cambiaría
#   POST collections/imports                 { file, mapping } → aplica el corte (Receivables::Snapshot) y recuerda el mapeo
#   GET  collections/imports                 los cortes
#   GET  collections/customers               ?filter=balance|pending|ignored|all &q= &page=
#   GET  collections/customers/:id           facturas, promesas, comprobantes y movimientos
#   POST collections/customers/:id/link      { contact_id } · create · ignore · POST customers/create_pending (todos)
#   GET  collections/promises ?status= · GET collections/claims ?status= · POST collections/claims/:id/validate|reject
class Api::V1::Accounts::CollectionsController < Api::V1::Accounts::BaseController
  PER_PAGE = 50
  MAPPING_KEY = 'receivables_mapping'
  TEMPLATE = ['Clave cliente', 'Cliente', 'RFC', 'Contacto', 'WhatsApp', 'Correo', 'Folio', 'Fecha factura', 'Vencimiento',
              'Total', 'Saldo', 'Moneda', 'Cobrador'].freeze

  before_action :require_admin
  before_action :set_customer, only: %i[customer link create_customer ignore]

  def overview
    agents = Current.account.tracking_templates.where(agent_function: 'collections', archived_at: nil).map { |t| { id: t.id, name: t.name } }
    render json: Receivables::Overview.call(Current.account).merge(agents: agents)
  end

  def template
    example = ['C-0153', 'Grúas del Norte SA de CV', 'GNO120304AB1', 'Laura Pérez', '8112345678', 'pagos@gruasnorte.mx', 'A-1234',
               '01/10/2026', '31/10/2026', '15000.00', '15000.00', 'MXN', '']
    send_data "﻿#{CSV.generate { |csv| csv << TEMPLATE << example }}", filename: 'cartera_kontrolya.csv', type: 'text/csv'
  end

  def preview
    sheet = spreadsheet
    snapshot = Receivables::Snapshot.new(Current.account, sheet.rows, source_ref: params[:file].original_filename)
    render json: { headers: sheet.headers, mapping: sheet.mapping, preview: snapshot.preview }
  rescue Receivables::Spreadsheet::Invalid => e
    render_error(e.message)
  end

  def create_import
    sheet = spreadsheet
    import = Receivables::Snapshot.new(Current.account, sheet.rows, user: current_user, source_ref: params[:file].original_filename).apply!
    remember_mapping(sheet.mapping)
    render json: import_json(import)
  rescue Receivables::Spreadsheet::Invalid => e
    render_error(e.message)
  end

  def imports
    render json: Current.account.receivable_imports.order(created_at: :desc).limit(50).map { |i| import_json(i) }
  end

  def customers
    scope = customers_scope.order(:name)
    render json: { total: scope.count, customers: scope.offset(page_offset).limit(PER_PAGE).map { |c| customer_json(c) } }
  end

  def customer
    render json: customer_json(@customer).merge(detail_json(@customer))
  end

  def link
    contact = Current.account.contacts.find(params[:contact_id])
    Receivables::Linker.new(Current.account).link!(@customer, contact)
    render json: customer_json(@customer.reload)
  end

  def create_customer
    Receivables::Linker.new(Current.account).create!(@customer)
    render json: customer_json(@customer.reload)
  rescue ActiveRecord::RecordInvalid => e
    render_error(e.record.errors.full_messages.to_sentence)
  end

  def ignore
    Receivables::Linker.new(Current.account).ignore!(@customer)
    render json: customer_json(@customer.reload)
  end

  def create_pending
    linker = Receivables::Linker.new(Current.account)
    errors = []
    Current.account.receivable_customers.pending.find_each do |c|
      linker.create!(c)
    rescue ActiveRecord::RecordInvalid => e
      errors << "#{c.name}: #{e.record.errors.full_messages.to_sentence}"
    end
    render json: { pending: Current.account.receivable_customers.pending.count, errors: errors.first(20) }
  end

  def promises
    scope = Current.account.payment_promises.includes(:receivable_customer).order(promised_on: :desc)
    scope = scope.where(status: params[:status]) if params[:status].present?
    render json: scope.limit(200).map { |p| promise_json(p) }
  end

  def claims
    scope = Current.account.payment_claims.includes(:receivable_customer).order(created_at: :desc)
    scope = scope.where(status: params[:status]) if params[:status].present?
    render json: scope.limit(200).map { |c| claim_json(c) }
  end

  def review_claim
    claim = Current.account.payment_claims.find(params[:id])
    return render_error('Ya se revisó.') unless claim.status == 'pending'

    Receivables::Claims.review!(claim, current_user, params[:decision] == 'validate', note: params[:note])
    render json: claim_json(claim.reload)
  end

  private

  def require_admin
    render json: { error: 'Solo administradores.' }, status: :forbidden unless access_grant.admin?
  end

  def render_error(message) = render(json: { error: message }, status: :unprocessable_entity)

  def spreadsheet
    raise Receivables::Spreadsheet::Invalid, 'Sube el archivo de la cartera (Excel o CSV).' if params[:file].blank?

    saved = Current.account.custom_attributes.to_h[MAPPING_KEY].to_h
    mapping = params[:mapping].present? ? params[:mapping].permit!.to_h : saved
    Receivables::Spreadsheet.new(params[:file], mapping: mapping)
  end

  def remember_mapping(mapping)
    Current.account.update!(custom_attributes: Current.account.custom_attributes.to_h.merge(MAPPING_KEY => mapping))
  end

  def set_customer
    @customer = Current.account.receivable_customers.find(params[:id])
  end

  def page_offset = ([params[:page].to_i, 1].max - 1) * PER_PAGE

  def customers_scope
    scope = Current.account.receivable_customers.includes(:contact, :organization, :collector)
    scope = case params[:filter]
            when 'pending' then scope.pending
            when 'ignored' then scope.where(link_status: 'ignored')
            when 'all' then scope
            else scope.where(id: Receivable.open_balance.where(account_id: Current.account.id).select(:receivable_customer_id))
            end
    return scope if params[:q].blank?

    scope.where('receivable_customers.name ILIKE :q OR receivable_customers.rfc ILIKE :q OR receivable_customers.external_key ILIKE :q',
                q: "%#{params[:q].to_s.strip}%")
  end

  def customer_json(customer)
    summary = Receivables::Summary.new(customer)
    customer.slice(:id, :external_key, :name, :rfc, :contact_name, :phone, :email, :link_status, :last_contacted_at, :touches)
            .merge(contact: customer.contact&.slice(:id, :name, :phone_number, :email),
                   organization: customer.organization&.slice(:id, :name), collector: customer.collector&.slice(:id, :name),
                   total: summary.total, overdue: summary.overdue_total, currency: summary.currency, stage: summary.stage,
                   invoices_count: summary.invoices.size, on_hold: customer.receivables.open_balance.where.not(claimed_at: nil)
                                                                   .or(customer.receivables.open_balance.where.not(disputed_at: nil)).count)
  end

  def detail_json(customer)
    { receivables: customer.receivables.order(status: :desc, due_on: :asc).limit(200)
                           .map do |r|
                     r.slice(:id, :folio, :issued_on, :due_on, :total, :balance, :currency, :status, :paid_at, :disputed_at,
                             :claimed_at)
                   end,
      promises: customer.payment_promises.order(created_at: :desc).limit(20).map { |p| promise_json(p) },
      claims: customer.payment_claims.order(created_at: :desc).limit(20).map { |c| claim_json(c) },
      conversation_id: customer.contact && Conversation.where(contact_id: customer.contact_id).order(last_activity_at: :desc).pick(:display_id) }
  end

  def promise_json(promise)
    promise.slice(:id, :promised_on, :amount, :status, :note, :created_at)
           .merge(customer: promise.receivable_customer.slice(:id, :name), conversation_id: display_id(promise.conversation_id))
  end

  def claim_json(claim)
    message = Message.find_by(id: claim.message_id) if claim.message_id
    claim.slice(:id, :amount, :note, :status, :reviewed_at, :created_at)
         .merge(customer: claim.receivable_customer.slice(:id, :name), conversation_id: display_id(claim.conversation_id),
                files: message ? message.attachments.map { |a| { name: a.file.filename.to_s, url: a.file_url, type: a.file_type } } : [])
  end

  def display_id(conversation_id) = conversation_id && Conversation.where(id: conversation_id).pick(:display_id)

  def import_json(import)
    import.slice(:id, :source, :source_ref, :stats, :created_at).merge(user: import.user&.name)
  end
end

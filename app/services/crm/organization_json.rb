# CrmZeus O1 — JSON de organizaciones y direcciones para la API (lista y detalle).
module Crm::OrganizationJson
  LIST_INCLUDES = [:seller, :rating, :customer_type, { home_address: { city: { state: :country } } }].freeze
  DETAIL_INCLUDES = [*CrmOrganization::LOOKUP_REFERENCES, :seller, :payment_term, :currency, :created_by, :updated_by,
                     { addresses: { city: { state: :country } } }].freeze

  module_function

  def list_item(org)
    {
      id: org.id, organization_type: org.organization_type, key: org.key, legal_name: org.legal_name,
      trade_name: org.trade_name, phone: org.phone, email: org.email, status: org.status,
      seller: named(org.seller), rating: named(org.rating), customer_type: named(org.customer_type),
      city: org.home_address&.city&.full_name, updated_at: org.updated_at.to_i
    }
  end

  def detail(org)
    home, consignees = org.addresses.partition(&:is_primary?)
    list_item(org).merge(admin_fields(org)).merge(reference_ids(org)).merge(
      notes: org.notes, converted_at: org.converted_at&.to_i, created_at: org.created_at.to_i,
      created_by: named(org.created_by), updated_by: named(org.updated_by),
      home_address: home.first && address(home.first), consignees: consignees.map { |item| address(item) }
    )
  end

  # Pestaña «Administración».
  def admin_fields(org)
    org.slice(:tax_id, :respect_seller, :suspended_on, :suspension_reason, :charge_taxes, :withholds_taxes, :cfdi_use,
              :sat_payment_form, :invoice_email).merge(credit_limit: org.credit_limit.to_f)
  end

  def address(item)
    item.slice(:id, :consignee_name, :street, :exterior_number, :interior_number, :neighborhood, :town, :reference,
               :city_id, :postal_code, :tax_id, :phone, :phone2, :email, :contact_name, :is_primary, :for_billing)
        .merge(city: item.city&.full_name, state_id: item.city&.state_id, country_id: item.city&.state&.country_id,
               full_address: item.full_address)
  end

  def reference_ids(org)
    (CrmOrganization::LOOKUP_REFERENCES + %i[seller payment_term currency]).to_h { |name| [:"#{name}_id", org[:"#{name}_id"]] }
  end

  def named(record)
    record && { id: record.id, name: record.name }
  end
end

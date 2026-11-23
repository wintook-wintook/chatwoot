# frozen_string_literal: true

# Cobranza — liga cada cliente de la cartera con su organización y el contacto al que se le cobra.
#   link_pending        los «por ligar»: por WhatsApp (últimos 10 dígitos), correo o RFC de la organización
#   link!(c, contact)   a mano: ese contacto (y su organización)
#   create!(c)          crea la organización (como cliente, con su RFC) y el contacto con los datos de la cartera
#   ignore!(c)          no se le cobra
class Receivables::Linker
  def initialize(account)
    @account = account
  end

  def link_pending
    @account.receivable_customers.pending.find_each do |customer|
      contact = contact_for(customer)
      link!(customer, contact) if contact
    end
  end

  def link!(customer, contact)
    organization = contact.organization || organization_by_rfc(customer.rfc)
    contact.update!(organization: organization) if organization && contact.organization_id.nil?
    customer.update!(contact: contact, organization: organization, link_status: 'linked')
  end

  def create!(customer)
    contact = contact_for(customer) || new_contact(customer)
    organization = contact.organization || organization_by_rfc(customer.rfc) || new_organization(customer, contact)
    link!(customer, contact.tap { |c| c.update!(organization: organization) if c.organization_id.nil? })
  end

  def ignore!(customer) = customer.update!(link_status: 'ignored')

  private

  def contact_for(customer)
    by_phone(customer.phone) || by_email(customer.email) || by_organization(customer.rfc)
  end

  def by_email(email) = email.present? ? @account.contacts.from_email(email) : nil

  def by_organization(rfc) = organization_by_rfc(rfc)&.contacts&.where&.not(phone_number: [nil, ''])&.first

  def by_phone(phone)
    digits = phone.to_s.gsub(/\D/, '').last(10)
    return nil if digits.length < 10

    @account.contacts.where("regexp_replace(phone_number, '[^0-9]', '', 'g') LIKE ?", "%#{digits}").order(:id).first
  end

  def organization_by_rfc(rfc)
    rfc.present? ? @account.organizations.find_by(tax_id: rfc) : nil
  end

  def new_contact(customer)
    @account.contacts.create!(name: customer.contact_name.presence || customer.name, email: customer.email.presence,
                              phone_number: customer.phone.presence,
                              additional_attributes: { 'company_name' => customer.name, 'source' => 'Cobranza' })
  end

  def new_organization(customer, contact)
    organization = Organization.build_for(contact, name: customer.name, tax_id: customer.rfc, stage: :customer)
    organization.save!
    organization
  end
end

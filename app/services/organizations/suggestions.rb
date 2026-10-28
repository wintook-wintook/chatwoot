# Plan-Organizaciones O4 — asistente para los contactos que ya existían: propone
# organizaciones agrupando a los que no tienen, sin aplicar nada (eso lo hace #apply con
# lo que el usuario confirme).
#
#   - Por la empresa escrita del contacto (additional_attributes.company_name / company).
#   - Sin empresa escrita, por el dominio de su correo (no los de correo gratuito).
#   - Sin ninguna de las dos pero con contrato u oportunidad ganada: Público en general con
#     su nombre (el cliente que es una persona).
#
# Etapa propuesta: cliente si alguno tiene contrato activo u oportunidad ganada; si no,
# prospecto. Si ya existe una organización con ese nombre, RFC o dominio, se propone ligarlos
# a ella en vez de crear otra.
class Organizations::Suggestions
  FREE_DOMAINS = %w[gmail.com hotmail.com hotmail.es outlook.com outlook.es live.com live.com.mx msn.com yahoo.com
                    yahoo.com.mx yahoo.es icloud.com me.com aol.com protonmail.com proton.me prodigy.net.mx
                    gmx.com mail.com].freeze
  LIMIT = 200

  def initialize(account:, contacts:)
    @account = account
    @contacts = contacts.where(organization_id: nil)
  end

  def call
    groups = {}
    @contacts.select(:id, :name, :email, :phone_number, :additional_attributes).find_each do |contact|
      type, value, label = group_key(contact)
      next unless type

      # Agrupa por lo normalizado; el nombre que se muestra es el del primero.
      (groups[[type, value]] ||= { label: label, contacts: [] })[:contacts] << contact
    end
    groups.map { |(type, value), group| suggestion([type, value, group[:label]], group[:contacts]) }
          .sort_by { |s| [s[:stage] == 'customer' ? 0 : 1, -s[:contacts].size, s[:name].downcase] }
          .first(LIMIT)
  end

  # Crea o liga lo confirmado: [{ name:, kind:, stage:, email_domain:, existing_organization_id:, contact_ids: [] }]
  def apply(groups, user)
    result = { created: 0, linked: 0 }
    Organization.transaction do
      Array(groups).each do |group|
        contacts = @contacts.where(id: Array(group[:contact_ids]))
        next if contacts.empty?

        organization = target_for(group, result, user)
        result[:linked] += contacts.update_all(organization_id: organization.id) # rubocop:disable Rails/SkipsModelValidations
      end
    end
    result
  end

  private

  def company_of(contact)
    attrs = contact.additional_attributes.to_h
    (attrs['company_name'].presence || attrs['company'].presence).to_s.squish.presence
  end

  def domain_of(contact)
    domain = contact.email.to_s.split('@')[1].to_s.downcase.strip
    domain.presence unless FREE_DOMAINS.include?(domain)
  end

  def group_key(contact)
    company = company_of(contact)
    return [:company, normalize(company), company] if company

    domain = domain_of(contact)
    return [:domain, domain, domain] if domain

    [:person, contact.id, contact.name] if activity_contact_ids.include?(contact.id)
  end

  def normalize(name)
    name.downcase.gsub(/[.,]/, ' ').gsub(/\b(s ?a|de|c ?v|s ?de ?r ?l|sapi|sc|inc|llc|ltd)\b/, ' ').squish
  end

  def suggestion(key, contacts)
    type, _value, label = key
    ids = contacts.map(&:id)
    existing = existing_for(type, label)
    {
      key: key.first(2).join(':'), source: type, name: existing&.name || label,
      kind: type == :person ? 'general_public' : 'company',
      stage: stage_for(ids),
      email_domain: type == :domain ? label : nil,
      existing_organization_id: existing&.id,
      contacts: contacts.map { |c| c.slice(:id, :name, :email, :phone_number) }
    }
  end

  def stage_for(contact_ids)
    contact_ids.intersect?(customer_contact_ids) ? 'customer' : 'prospect'
  end

  def existing_for(type, label)
    return if type == :person
    return @account.organizations.find_by(email_domain: label) if type == :domain

    @account.organizations.where('LOWER(name) = ?', label.downcase).first
  end

  # Contrato activo u oportunidad ganada → cliente.
  def customer_contact_ids
    @customer_contact_ids ||= (@account.contracts.active.pluck(:contact_id) +
                               @account.case_tickets.outcome_won.pluck(:contact_id)).compact.uniq
  end

  def activity_contact_ids
    customer_contact_ids
  end

  def target_for(group, result, user)
    existing = group[:existing_organization_id].presence && @account.organizations.find_by(id: group[:existing_organization_id])
    return existing if existing

    stage = group[:stage].to_s == 'customer' ? :customer : :prospect
    kind = group[:kind].to_s == 'general_public' ? :general_public : :company
    organization = @account.organizations.create!(name: group[:name], kind: kind, stage: stage,
                                                  email_domain: group[:email_domain])
    organization.events.create!(user: user, action: 'created', data: { to: stage.to_s, reason: 'import_assistant' })
    result[:created] += 1
    organization
  end
end

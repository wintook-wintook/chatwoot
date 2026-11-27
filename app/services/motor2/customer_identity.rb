# frozen_string_literal: true

# Motor 2.0 — ¿de qué empresa es quien escribe? El contacto ya lo crea Kontrolya solo (número de
# WhatsApp o correo); lo que falta es ligarlo a su organización:
#   - by_domain!: si escribe desde un correo de empresa (no gmail, hotmail…) y hay una organización con
#     ese dominio, se liga sola (antes de decidir si es cliente: Motor2::ClientCheck);
#   - find: la empresa que dijo él (nombre exacto o RFC; si no, la única que se parezca) — la usa
#     Motor2::Skills::Identity cuando el agente le pregunta.
module Motor2::CustomerIdentity
  FREE_DOMAINS = %w[gmail.com googlemail.com hotmail.com hotmail.es outlook.com outlook.es live.com live.com.mx msn.com
                    yahoo.com yahoo.com.mx yahoo.es icloud.com me.com aol.com prodigy.net.mx protonmail.com proton.me].freeze

  module_function

  def by_domain!(contact)
    return contact&.organization if contact.nil? || contact.organization

    domain = corporate_domain(contact.email)
    org = domain && contact.account.organizations.find_by(email_domain: domain)
    contact.update!(organization: org) if org
    org
  rescue StandardError => e
    Rails.logger.warn("[Motor2::CustomerIdentity] contacto #{contact&.id}: #{e.class}: #{e.message}")
    nil
  end

  def corporate_domain(email)
    domain = email.to_s.split('@')[1].to_s.downcase.strip
    domain.present? && FREE_DOMAINS.exclude?(domain) ? domain : nil
  end

  def find(account, said)
    text = said.to_s.squish
    return nil if text.length < 2

    scope = account.organizations
    exact = scope.find_by('LOWER(organizations.name) = :n OR UPPER(organizations.tax_id) = :t', n: text.downcase, t: text.upcase)
    return exact if exact

    similar = scope.search(text).limit(2).to_a
    similar.size == 1 ? similar.first : nil
  end
end

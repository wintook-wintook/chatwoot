# frozen_string_literal: true

# Motor 2.0 — «Atención a clientes»: lo que Kontrolya ya sabe de quien escribe, para no preguntarle lo
# que ya se sabe (Motor2::Skills::Identity lo pone en la memoria del agente):
#   - su empresa y si es cliente o prospecto;
#   - los sistemas que usa (los Servicios afectados de los casos de su empresa, los más frecuentes);
#   - sus casos abiertos (solo los suyos) y los contratos vigentes de su empresa.
# Solo es contexto para ayudar: el agente no da datos de la cuenta (montos, facturas, casos de otros).
module Motor2::CustomerContext
  MAX = 3

  module_function

  def lines(contact)
    return [] unless contact

    [company_line(contact.organization), systems_line(contact), cases_line(contact), contracts_line(contact)].compact
  end

  # Los sistemas que usa su empresa (o él, si no tiene empresa), del más frecuente al menos.
  def systems(contact)
    return [] unless contact

    ids = contact.organization ? contact.organization.contacts.pluck(:id) : [contact.id]
    counts = CaseTicket.where(account_id: contact.account_id, contact_id: ids).where.not(affected_service_id: nil)
                       .group(:affected_service_id).count.sort_by { |_, n| -n }.first(MAX).map(&:first)
    names = CaseService.where(id: counts).index_by(&:id)
    counts.filter_map { |id| names[id]&.name }
  end

  def company_line(org)
    return nil unless org

    "SU EMPRESA: #{org.name} (#{org.customer? ? 'cliente' : 'prospecto'})"
  end

  def systems_line(contact)
    list = systems(contact)
    "SISTEMAS QUE USA (por sus casos): #{list.join(', ')}" if list.any?
  end

  def cases_line(contact)
    open = CaseTicket.where(account_id: contact.account_id, contact_id: contact.id).where.not(status: CaseTicket::CLOSED_STATUSES)
                     .order(created_at: :desc).limit(MAX)
    return nil if open.empty?

    "SUS CASOS ABIERTOS: #{open.map { |t| "#{t.try(:folio) || t.id} «#{t.title.to_s.first(60)}» (#{t.status})" }.join('; ')}"
  end

  def contracts_line(contact)
    scope = Contract.where(account_id: contact.account_id, status: :active)
    mine = scope.where(contact_id: contact.id)
    scope = contact.organization ? scope.where(organization_id: contact.organization_id).or(mine) : mine
    titles = scope.order(:id).limit(MAX).pluck(:title)
    "SUS CONTRATOS VIGENTES: #{titles.join('; ')}" if titles.any?
  end
end

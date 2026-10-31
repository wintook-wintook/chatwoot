# Plan-Organizaciones — lo del contacto que pertenece a una organización: oportunidades y
# casos, cotizaciones, contratos, equipos y planes de mantenimiento. «Vivo» es lo que todavía
# corre (lo que pasa al sustituto cuando el contacto se va sin llevárselo); lo demás es historial.
# Tareas y tareas agendadas: solo las que no tienen caso; las de un caso van con su caso.
class Organizations::ContactRecords
  KINDS = %i[case_tickets quotes contracts customer_assets maintenance_plans case_tasks case_meetings].freeze

  def initialize(contact)
    @contact = contact
    @account = contact.account
  end

  # Todo lo del contacto en esa organización (nil = lo que no tiene organización).
  def in(organization_id)
    KINDS.index_with { |kind| @account.public_send(kind).where(contact_id: @contact.id, organization_id: organization_id) }
  end

  def live_in(organization_id)
    scopes = self.in(organization_id)
    {
      case_tickets: scopes[:case_tickets].where.not(status: CaseTicket::CLOSED_STATUSES),
      quotes: scopes[:quotes].where(status: Quote::LIVE_STATUSES),
      contracts: scopes[:contracts].where.not(status: :cancelled),
      customer_assets: scopes[:customer_assets].active,
      maintenance_plans: scopes[:maintenance_plans].active,
      case_tasks: scopes[:case_tasks].pending,
      case_meetings: scopes[:case_meetings].active
    }
  end

  # { case_tickets: n, … } de lo que hay en la organización: todo y lo vivo.
  def counts(organization_id)
    { all: count(self.in(organization_id)), live: count(live_in(organization_id)) }
  end

  # Lo que no tenía organización pasa a la suya (al ligarlo por primera vez).
  def adopt_unlinked!(organization_id)
    bulk_update(self.in(nil), organization_id: organization_id)
  end

  # Lo mismo para varios contactos ligados de una vez (asistente, importaciones).
  def self.adopt_unlinked_for!(account, contact_ids, organization_id)
    KINDS.sum do |kind|
      account.public_send(kind).where(contact_id: contact_ids, organization_id: nil)
             .update_all(organization_id: organization_id, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  def move!(from_id, to_id)
    bulk_update(self.in(from_id), organization_id: to_id)
  end

  # Lo vivo de la organización que deja pasa al contacto que queda en su lugar.
  def hand_over_live!(organization_id, replacement)
    bulk_update(live_in(organization_id), contact_id: replacement.id)
  end

  private

  def count(scopes)
    scopes.transform_values(&:count)
  end

  def bulk_update(scopes, attrs)
    scopes.values.sum { |scope| scope.update_all(attrs.merge(updated_at: Time.current)) } # rubocop:disable Rails/SkipsModelValidations
  end
end

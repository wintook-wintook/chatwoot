# frozen_string_literal: true

# Campaña con IA · Recordar — mete a cada contrato cuando le toca, con sus toques en FECHAS según su vencimiento.
#
#   brief['renew_source'] = { 'contract_type_id' => 3 (o nil: todos), 'offsets' => [7, 1, 0] }   días antes de que venza
#
# Cada día (TrackingCampaigns::RenewEnrollJob) y al lanzarla: los contratos activos que se cobran o terminan dentro del
# mayor de los días (el más próximo de cada contacto) entran a la campaña (TrackingCampaigns::Enroll: mismas reglas de
# siempre) ligados a su contrato; el primer toque en la primera fecha que no haya pasado y los demás en
# motor2_state['schedule'] (ContactTrackings::DueSchedule). Un contacto entra una sola vez por campaña.
class TrackingCampaigns::RenewEnroll
  HOUR = 10 # los toques salen a las 10 de la mañana de su día (hora de la bandeja)
  MAX_OFFSETS = 4

  def self.sanitize(raw)
    raw = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
    offsets = Array(raw['offsets']).map(&:to_i).select { |n| n.between?(0, 60) }.uniq.sort.reverse.first(MAX_OFFSETS)
    { 'contract_type_id' => raw['contract_type_id'].to_s.presence&.to_i, 'offsets' => offsets.presence || [7, 1, 0] }.compact
  end

  def self.campaigns
    TrackingCampaign.where(engine: '2', status: 'running').where("brief ->> 'kind' = 'renew'").where("brief ? 'renew_source'")
  end

  def initialize(campaign)
    @campaign = campaign
    @source = self.class.sanitize(campaign.brief.to_h['renew_source'])
  end

  def call
    return 0 unless %w[running draft].include?(@campaign.status)

    due_contracts.count { |contract, due| enroll(contract, due) }
  end

  # [contrato, vence] — el más próximo de cada contacto que todavía no está en la campaña.
  def due_contracts
    taken = @campaign.entries.pluck(:contact_id)
    scope = Contract.where(account_id: @campaign.account_id, status: :active).where.not(contact_id: taken)
    scope = scope.where(contract_type_id: @source['contract_type_id']) if @source['contract_type_id']
    scope.where('LEAST(COALESCE(next_charge_on, ends_on), COALESCE(ends_on, next_charge_on)) BETWEEN ? AND ?',
                Date.current, Date.current + @source['offsets'].max)
         .map { |c| [c, [c.next_charge_on, c.ends_on].compact.min] }
         .group_by { |c, _| c.contact_id }.map { |_, rows| rows.min_by(&:last) }
  end

  private

  def enroll(contract, due)
    times = schedule(due)
    entry = TrackingCampaigns::Enroll.new(@campaign, contract.contact, source: 'renew', at: times.first).call
    tracking = entry.status == 'enrolled' ? entry.contact_tracking : nil
    return false unless tracking

    # Si el horario de la bandeja movió el primero (fin de semana), no dos el mismo día.
    rest = times.drop(1).select { |at| at > tracking.scheduled_for + 12.hours }
    tracking.update_columns(contract_id: contract.id, max_attempts: 1 + rest.size, updated_at: Time.current, # rubocop:disable Rails/SkipsModelValidations
                            motor2_state: tracking.motor2_state.to_h.merge('due_on' => due.iso8601, 'schedule' => rest.map(&:iso8601)))
    true
  end

  # Las fechas de sus toques que no han pasado (si todas pasaron, ya).
  def schedule(due)
    zone = @campaign.inbox&.timezone.presence || 'America/Mexico_City'
    times = @source['offsets'].map { |days| Time.find_zone(zone).local(due.year, due.month, due.day, HOUR) - days.days }
    upcoming = times.select(&:future?)
    upcoming.presence || [Time.current]
  end
end

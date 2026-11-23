# frozen_string_literal: true

# Campaña con Vendedor IA — «Prueba real»: la campaña completa, de verdad, pero solo a los contactos de prueba (tú o
# tu equipo). Es una copia de la campaña (test_of_id) que:
#   · va solo a esos contactos (hasta MAX_RECIPIENTS), sin tope diario, sin horario hábil, sin calentar ni descanso;
#   · manda los toques cada `every_minutes` minutos (Motor2Brief.pace) y los recordatorios del vendedor en minutos
#     en lugar de horas (Motor2::FollowUp.hours);
#   · crea las conversaciones, el relevo, las citas y las notas de verdad;
#   · no aparece en el listado de campañas ni cuenta en los resultados de la campaña (es otra campaña).
# Una prueba nueva termina la anterior. «Terminar» cancela los toques que falten.
#
#   run = TrackingCampaigns::Motor2TestRun.new(campaign, user)
#   run.start(recipients: [{ contact_id: 1 }, { email: 'yo@x.com' }, { phone: '+5281…' }], every_minutes: 3)
#   run.status → { run: {…}, contacts: [ { name, address, entry, tracking, messages } ] } · run.stop
class TrackingCampaigns::Motor2TestRun
  MAX_RECIPIENTS = 5
  LIVE = %w[pending scheduled active paused].freeze

  def initialize(campaign, user)
    @campaign = campaign
    @account = campaign.account
    @user = user
  end

  def start(recipients:, every_minutes: nil)
    error = setup_error
    return { error: error } if error

    contacts = recipient_contacts(recipients)
    return { error: contacts[:error] } if contacts.is_a?(Hash)

    stop
    run = create_copy(every_minutes)
    contacts.each { |contact| TrackingCampaigns::Enroll.new(run, contact, source: 'batch', agent: @user).call }
    { run: run }
  end

  def stop
    @campaign.test_runs.where.not(status: 'finished').find_each do |run|
      run.contact_trackings.where(status: LIVE).find_each(&:cancel!)
      run.update!(status: 'finished')
    end
  end

  def latest = @campaign.test_runs.order(:id).last

  def status
    run = latest
    return { run: nil, contacts: [] } unless run

    { run: { id: run.id, status: run.status, started_at: run.scheduled_for, every_minutes: run.touches.to_h['test_every_minutes'],
             attempts: run.touches.to_h['attempts'] },
      contacts: run.entries.includes(:contact, contact_tracking: :conversation).order(:id).map { |e| entry_json(e) } }
  end

  private

  def whatsapp? = @campaign.inbox&.whatsapp?

  def setup_error
    return 'Elige el vendedor y el canal de la campaña.' unless @campaign.tracking_template && @campaign.inbox
    return 'Para WhatsApp, el primer toque necesita una plantilla aprobada.' if whatsapp? && Array(@campaign.touches.to_h['templates']).first.blank?

    nil
  end

  # Los contactos de prueba: uno que ya existe, o uno por su correo / teléfono (se busca y, si no está, se crea).
  def recipient_contacts(recipients)
    list = Array(recipients).map { |r| r.to_h.symbolize_keys }.first(MAX_RECIPIENTS)
    return { error: 'Agrega al menos un contacto de prueba.' } if list.empty?

    contacts = list.map { |r| contact_for(r) }
    bad = list.zip(contacts).find { |_, c| c.nil? }
    return { error: "No se pudo usar «#{bad.first.values.compact_blank.first}»: revisa el dato." } if bad

    contacts.uniq(&:id)
  end

  def contact_for(recipient)
    return @account.contacts.find_by(id: recipient[:contact_id]) if recipient[:contact_id].present?

    email = recipient[:email].to_s.strip.downcase.presence
    phone = phone(recipient[:phone])
    return nil unless email || phone

    found = email ? @account.contacts.where('LOWER(email) = ?', email).first : @account.contacts.find_by(phone_number: phone)
    found || @account.contacts.create(name: "Prueba · #{@user.name}", email: email, phone_number: phone).then { |c| c.persisted? ? c : nil }
  end

  def phone(raw)
    digits = raw.to_s.gsub(/[^\d+]/, '')
    return nil if digits.blank?

    digits.start_with?('+') ? digits : "+#{digits}"
  end

  COPIED = %i[tracking_template_id inbox_id objective purpose brief touches email_subject email_subject_b event_id event_status engine].freeze

  def create_copy(every_minutes)
    minutes = (every_minutes.presence || TrackingCampaigns::Motor2Brief::TEST_EVERY_MINUTES).to_i.clamp(1, 60)
    now = Time.current
    @account.tracking_campaigns.create!(
      @campaign.slice(*COPIED).merge(
        name: "🧪 Prueba · #{@campaign.name}".first(120), test_of: @campaign, user: @user, mode: 'batch', status: 'running',
        scheduled_for: now, ends_at: nil, daily_cap: nil, respect_working_hours: false, entry_delay_minutes: 0, audience: {},
        brief: @campaign.brief.to_h.merge('rest_days' => 0, 'warmup' => false).except('insights'),
        touches: @campaign.touches.to_h.merge('test_every_minutes' => minutes)
      )
    )
  end

  def entry_json(entry)
    contact = entry.contact
    tracking = entry.contact_tracking
    { contact_id: contact&.id, name: contact&.name, address: whatsapp? ? contact&.phone_number : contact&.email,
      status: entry.status, reason: entry.reason, tracking: tracking && tracking_json(tracking),
      messages: tracking&.conversation ? messages(tracking.conversation) : [] }
  end

  def tracking_json(tracking)
    { status: tracking.status, attempt: tracking.attempt_count, attempts: tracking.max_attempts,
      next_at: LIVE.include?(tracking.status) ? tracking.scheduled_for : nil, outcome: tracking.outcome,
      stage: tracking.prospect_stage, error: tracking.last_error, conversation_id: tracking.conversation&.display_id }
  end

  # Lo que pasó en la conversación: lo que salió, lo que contestó y las notas (relevo, cita, no le interesa…).
  def messages(conversation)
    conversation.messages.where(message_type: %i[incoming outgoing]).reorder(id: :desc).limit(12).to_a.reverse.map do |m|
      { id: m.id, kind: m.private ? 'note' : m.message_type, content: m.content.to_s.first(600), at: m.created_at }
    end
  end
end

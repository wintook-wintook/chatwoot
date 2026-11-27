# frozen_string_literal: true

require 'csv'

# Campaña con Vendedor IA por CORREO — subir una lista fría (CSV) a la campaña, sin llenar Contactos de basura:
#   1. se limpia antes de crear nada: sin correo o mal escrito, dominio que no recibe, repetido en la lista, de rol
#      (info@, ventas@…), que se dio de baja o rebotó antes (contacto o EmailSuppression);
#   2. si el correo ya es de un contacto, se usa ese (no se duplica ni se pone en cuarentena);
#   3. los nuevos se crean en cuarentena (list_quarantine): no salen en Contactos hasta que contestan.
# Columnas (encabezados, sin importar mayúsculas ni acentos): correo/email, nombre/name, empresa/company,
# teléfono/phone. La audiencia de la campaña queda con esos contactos.
#
#   ProspectLists::Import.new(campaign, user, file, name:, cleanup_days:).call → { list: } | { error: }
class ProspectLists::Import
  MAX_ROWS = 5000
  DNS_BUDGET = 20.seconds
  ROLE = /\A(info|informes|contacto|contact|ventas|sales|admin|administracion|administración|soporte|support|noreply|no-reply|
           donotreply|facturacion|facturación|rh|recursoshumanos|webmaster|postmaster|abuse|marketing|hola|hello)@/xi
  HEADERS = { email: %w[correo email e-mail mail correo_electronico], name: %w[nombre name nombre_completo contacto],
              company: %w[empresa company compania compañia organizacion], phone: %w[telefono teléfono phone celular] }.freeze

  def initialize(campaign, user, file, name: nil, cleanup_days: 30)
    @campaign = campaign
    @account = campaign.account
    @user = user
    @file = file
    @name = name.presence || "Lista #{I18n.l(Time.current.to_date)}"
    @cleanup_days = cleanup_days.to_i.clamp(1, 365)
    @discarded = Hash.new(0)
  end

  def call
    return { error: 'La lista solo se puede usar en campañas por correo.' } unless @campaign.inbox&.email?

    rows = parse
    return { error: rows } if rows.is_a?(String)

    list = ProspectList.create!(account: @account, tracking_campaign: @campaign, uploaded_by: @user, name: @name.first(160),
                                cleanup_days: @cleanup_days)
    ids, created, existing = load_contacts(clean(rows), list)
    list.update!(stats: { 'rows' => rows.size, 'valid' => ids.size, 'created' => created, 'existing' => existing,
                          'discarded' => @discarded, 'contact_ids' => ids })
    @campaign.update!(audience: { 'source' => { 'type' => 'list', 'list_id' => list.id, 'name' => list.name },
                                  'contact_ids' => ids, 'excluded_contact_ids' => [], 'skip_active' => true })
    { list: list }
  end

  private

  def parse
    table = CSV.parse(text, headers: true, col_sep: separator)
    return 'La lista está vacía.' if table.empty?
    return "La lista trae más de #{MAX_ROWS} renglones: divídela." if table.size > MAX_ROWS

    columns = column_map(table.headers)
    return 'No encontré la columna de correo (correo o email).' unless columns[:email]

    table.map { |row| columns.transform_values { |h| row[h].to_s.strip } }
  rescue CSV::MalformedCSVError
    'El archivo no es un CSV válido.'
  end

  def text = @text ||= @file.read.to_s.force_encoding('UTF-8').scrub.delete_prefix("\uFEFF")

  # Excel en español guarda con «;».
  def separator
    first = text.lines.first.to_s
    first.count(';') > first.count(',') ? ';' : ','
  end

  def column_map(headers)
    plain = headers.compact.index_by { |h| I18n.transliterate(h.to_s).downcase.strip.tr(' ', '_') }
    HEADERS.transform_values { |names| names.map { |n| I18n.transliterate(n) }.filter_map { |n| plain[n] }.first }.compact
  end

  def clean(rows)
    seen = Set.new
    kept = rows.filter_map do |row|
      email = row[:email].to_s.downcase
      reason = reject_reason(email, seen)
      seen << email
      reason ? discard(reason) : row.merge(email: email)
    end
    dead = dead_domains(kept.map { |r| r[:email].split('@').last }.uniq)
    kept.reject { |r| dead.include?(r[:email].split('@').last) && discard('undeliverable') }
  end

  def discard(reason)
    @discarded[reason] += 1
    nil
  end

  def reject_reason(email, seen)
    return 'invalid' unless Devise.email_regexp.match?(email)
    return 'duplicate' if seen.include?(email)
    return 'role' if email.match?(ROLE)

    'suppressed' if suppressed.include?(email)
  end

  # Los dominios que no reciben correo (MX). Con tiempo límite: los que no alcancen a revisarse los vuelve a revisar la
  # inscripción (TrackingCampaigns::Enroll → «correo inválido»).
  def dead_domains(domains)
    deadline = DNS_BUDGET.from_now
    domains.each_with_object(Set.new) do |domain, dead|
      break dead if Time.current > deadline

      dead << domain unless ContactTrackings::EmailCheck.domain_receives_mail?(domain)
    end
  end

  # Los que no se vuelven a cargar: la lista de exclusión y los contactos dados de baja o con rebote.
  def suppressed
    @suppressed ||= Set.new(EmailSuppression.where(account_id: @account.id).pluck(:email)) |
                    @account.contacts.where.not(opted_out_at: nil).or(@account.contacts.where.not(email_bounced_at: nil))
                            .pluck(:email).compact.map(&:downcase)
  end

  def load_contacts(rows, list)
    known = @account.contacts.where('LOWER(email) IN (?)', rows.pluck(:email).presence || ['']).index_by { |c| c.email.downcase }
    created = 0
    ids = rows.filter_map do |row|
      next known[row[:email]].id if known[row[:email]]

      created += 1
      new_contact(row, list).id
    rescue ActiveRecord::RecordInvalid
      @discarded['invalid'] += 1
      created -= 1
      nil
    end
    [ids, created, ids.size - created]
  end

  def new_contact(row, list)
    @account.contacts.create!(name: row[:name].presence || row[:email].split('@').first, email: row[:email],
                              phone_number: nil, prospect_list: list, list_quarantine: true,
                              additional_attributes: { 'company_name' => row[:company].presence, 'source' => "Lista: #{list.name}" }.compact)
  end
end

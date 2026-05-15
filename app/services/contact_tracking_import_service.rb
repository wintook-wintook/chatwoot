# frozen_string_literal: true

# ================================================================================
# proyecto@import_seguimiento
# ================================================================================
# Servicio: ContactTrackingImportService
# Descripción: Importa contactos desde un archivo Excel/CSV hacia contact_trackings.
#              Parsea XLSX con rubyzip + nokogiri (ya en el bundle).
#              Parsea CSV con la librería estándar de Ruby.
#
# Columnas esperadas en el archivo:
#   Requeridas:
#     - template_name   → nombre exacto de la TrackingTemplate (account-scoped)
#     - scheduled_for   → fecha/hora del primer intento (ej: "2026-04-01 09:00")
#     - contact_phone   → teléfono del contacto (al menos uno de phone o name)
#     - contact_name    → nombre exacto del contacto (al menos uno de phone o name)
#   Opcionales:
#     - inbox_id              → solo si la plantilla no tiene inbox definido
#     - max_attempts          → default: 3
#     - retry_interval_value  → default: 30
#     - retry_interval_unit   → default: "minutes"
#     - ai_context            → override del contexto de la plantilla
#     - complementary_prompt  → override del prompt complementario
#
# Retorna:
#   { inserted: N, skipped: N, errors: [{ row: N, message: "..." }] }
# ================================================================================

class ContactTrackingImportService
  REQUIRED_COLUMNS = %w[template_name scheduled_for].freeze
  CONTACT_COLUMNS  = %w[contact_phone contact_name].freeze
  ACTIVE_STATUSES  = %w[pending scheduled active paused].freeze

  DEFAULT_MAX_ATTEMPTS   = 3
  DEFAULT_INTERVAL_VALUE = 30
  DEFAULT_INTERVAL_UNIT  = 'minutes'

  MAX_IMPORT_ROWS = 50 # Límite máximo de seguimientos por importación

  def initialize(account:, file:, current_user: nil)
    @account      = account
    @file         = file
    @current_user = current_user
    @results      = { inserted: 0, skipped: 0, errors: [] }
  end

  def call
    rows = open_spreadsheet
    return { inserted: 0, skipped: 0, errors: [{ row: 'archivo', message: 'El archivo está vacío' }] } if rows.empty?

    headers = normalize_headers(rows[0])
    validate_headers!(headers)

    data_rows = rows[1..].reject { |r| row_blank?(headers.zip(r.map { |v| v.to_s.strip.presence }).to_h) }

    return { inserted: 0, skipped: 0, errors: [{ row: 'archivo', message: 'El archivo no contiene datos. Agrega al menos una fila con información.' }] } if data_rows.empty?

    if data_rows.length > MAX_IMPORT_ROWS
      return { inserted: 0, skipped: 0, errors: [{ row: 'archivo', message: "El archivo excede el límite de #{MAX_IMPORT_ROWS} seguimientos. Tiene #{data_rows.length} filas con datos." }] }
    end

    rows[1..].each_with_index do |row_values, idx|
      row_number = idx + 2
      row_data   = headers.zip(row_values.map { |v| v.to_s.strip.presence }).to_h
      next if row_blank?(row_data)

      process_row(row_number, row_data)
    end

    @results
  rescue StandardError => e
    Rails.logger.error "[ContactTrackingImport] Error: #{e.message}"
    { inserted: 0, skipped: 0, errors: [{ row: 'archivo', message: e.message }] }
  end

  private

  # ============================================================
  # Parseo del archivo — sin gems externas extra
  # XLSX: rubyzip + nokogiri (ya en el bundle de Chatwoot)
  # CSV:  stdlib Ruby
  # ============================================================

  def open_spreadsheet
    ext = File.extname(@file.original_filename).downcase
    case ext
    when '.xlsx' then parse_xlsx(@file.path)
    when '.csv'  then parse_csv(@file.path)
    else raise "Formato no soportado: #{ext}. Usa .xlsx o .csv"
    end
  end

  # Parsea XLSX usando `unzip` del sistema operativo + Nokogiri (ya cargado en el proceso).
  # No requiere ninguna gem extra — unzip está disponible en cualquier Linux.
  def parse_xlsx(path)
    require 'tmpdir'
    require 'open3'

    rows = []

    Dir.mktmpdir('cw_import') do |dir|
      _out, err, status = Open3.capture3('unzip', '-q', path, '-d', dir)
      raise "No se pudo leer el archivo XLSX: #{err}" unless status.success?

      # 1. Strings compartidos
      shared_strings = []
      ss_path = File.join(dir, 'xl', 'sharedStrings.xml')
      if File.exist?(ss_path)
        ss_doc = Nokogiri::XML(File.read(ss_path))
        ss_doc.remove_namespaces!
        shared_strings = ss_doc.xpath('//si').map do |si|
          si.xpath('.//t').map(&:text).join
        end
      end

      # 2. Primera hoja disponible
      sheet_path = Dir.glob(File.join(dir, 'xl', 'worksheets', '*.xml'))
                      .reject { |f| File.basename(f).start_with?('_') }
                      .min_by { |f| File.basename(f) }
      return rows unless sheet_path

      sheet_doc = Nokogiri::XML(File.read(sheet_path))
      sheet_doc.remove_namespaces!

      sheet_doc.xpath('//row').each do |row_node|
        row_map = {}

        row_node.xpath('c').each do |cell|
          ref       = cell['r'].to_s
          col_str   = ref.gsub(/\d+/, '')
          col_index = col_letter_to_index(col_str)

          raw_value = cell.xpath('v').text.presence
          value = if cell['t'] == 's'
                    shared_strings[raw_value.to_i]
                  elsif cell['t'] == 'inlineStr'
                    cell.xpath('.//t').text.presence
                  else
                    raw_value
                  end

          row_map[col_index] = value
        end

        max_col   = row_map.keys.max || 0
        row_array = (0..max_col).map { |i| row_map[i] }
        rows << row_array
      end
    end

    rows
  end

  # Convierte letras de columna Excel a índice 0-based: A→0, B→1, Z→25, AA→26
  def col_letter_to_index(letters)
    letters.upcase.chars.reduce(0) do |acc, char|
      acc * 26 + (char.ord - 'A'.ord + 1)
    end - 1
  end

  # Parsea CSV con la librería estándar de Ruby
  def parse_csv(path)
    require 'csv'
    CSV.read(path, encoding: 'UTF-8')
  rescue CSV::MalformedCSVError
    CSV.read(path, encoding: 'ISO-8859-1:UTF-8')
  end

  # ============================================================
  # Validación de columnas
  # ============================================================

  def normalize_headers(header_row)
    header_row.map { |h| h.to_s.strip.downcase.gsub(/\s+/, '_') }
  end

  def validate_headers!(headers)
    missing = REQUIRED_COLUMNS.reject { |col| headers.include?(col) }
    raise "Columnas requeridas faltantes: #{missing.join(', ')}" if missing.any?

    has_contact = CONTACT_COLUMNS.any? { |col| headers.include?(col) }
    raise 'El archivo debe incluir al menos una columna: contact_phone o contact_name' unless has_contact
  end

  # ============================================================
  # Procesamiento de cada fila
  # ============================================================

  def process_row(row_number, row_data)
    # 1. Buscar TrackingTemplate por nombre exacto
    template_name = row_data['template_name'].to_s.strip
    template = @account.tracking_templates.find_by(name: template_name)
    unless template
      add_error(row_number, "Plantilla '#{template_name}' no encontrada")
      return
    end

    # 2. Buscar contacto — si no existe, crearlo con los datos del Excel
    contact = find_or_create_contact(row_data, row_number)
    return unless contact

    # 3. Si ya tiene tracking activo → omitir
    if ContactTracking.where(contact_id: contact.id, status: ACTIVE_STATUSES).exists?
      @results[:skipped] += 1
      return
    end

    # 4. Resolver inbox_id y conversation_id (necesario antes de parsear la fecha
    #    para obtener el timezone correcto de la bandeja de entrada)
    inbox_id, conversation_id = resolve_inbox_and_conversation(contact, template, row_data)
    unless inbox_id
      add_error(row_number, 'No se pudo determinar el inbox. Define inbox_id en el Excel o en la plantilla.')
      return
    end

    # 5. Parsear scheduled_for usando el timezone de la bandeja de entrada
    inbox_tz = @account.inboxes.find_by(id: inbox_id)&.timezone.presence || 'UTC'
    scheduled_for = parse_datetime(row_data['scheduled_for'], inbox_tz)
    unless scheduled_for
      add_error(row_number, "Fecha 'scheduled_for' inválida: '#{row_data['scheduled_for']}'")
      return
    end

    # Rechazar fechas pasadas
    if scheduled_for <= Time.current
      add_error(row_number, "La fecha '#{scheduled_for.strftime('%d/%m/%Y %H:%M')}' ya pasó. El seguimiento debe programarse en el futuro.")
      return
    end

    # 6. Si no hay conversación → abrir una con nota privada (igual que proyecto@commands_agents)
    if conversation_id.nil?
      conversation = open_conversation_with_private_note(contact, inbox_id)
      conversation_id = conversation&.id
    end

    # 7. Crear ContactTracking
    create_tracking(contact, inbox_id, conversation_id, template, scheduled_for, row_data, row_number)
  rescue StandardError => e
    Rails.logger.error "[ContactTrackingImport] Error en fila #{row_number}: #{e.message}"
    add_error(row_number, "Error inesperado: #{e.message}")
  end

  # ============================================================
  # Creación del registro
  # ============================================================

  def create_tracking(contact, inbox_id, conversation_id, template, scheduled_for, row_data, row_number)
    now = Time.current

    # insert! bypasea validaciones Y callbacks del modelo (after_create :schedule_job).
    # Esto preserva scheduled_for exactamente como viene del Excel, sin que el job
    # se dispare inmediatamente y reagende la fecha.
    result = ContactTracking.insert!(
      {
        account_id:           @account.id,
        contact_id:           contact.id,
        inbox_id:             inbox_id,
        conversation_id:      conversation_id,
        objective:            template.objective,
        scheduled_for:        scheduled_for,
        max_attempts:         int_or_default(row_data['max_attempts'], DEFAULT_MAX_ATTEMPTS),
        attempt_count:        0,
        retry_interval_value: int_or_default(row_data['retry_interval_value'], DEFAULT_INTERVAL_VALUE),
        retry_interval_unit:  str_or_default(row_data['retry_interval_unit'], DEFAULT_INTERVAL_UNIT),
        ai_context:           row_data['ai_context'].presence || template.ai_context,
        complementary_prompt: row_data['complementary_prompt'].presence || template.complementary_prompt,
        whatsapp_templates:   template.whatsapp_templates || [],
        response_adjustments_count: 0,
        status:               'pending',
        created_at:           now,
        updated_at:           now
      },
      returning: [:id]
    )

    tracking_id = result.rows.first.first

    # Programar el job en la fecha exacta del Excel (ya validada como futura).
    ContactTrackingJob.set(wait_until: scheduled_for).perform_later(tracking_id)

    @results[:inserted] += 1
  rescue StandardError => e
    add_error(row_number, "Error al crear tracking: #{e.message}")
  end

  # ============================================================
  # Helpers de resolución
  # ============================================================

  # Abre una conversación con nota privada cuando el contacto no tiene ninguna.
  # Replica el patrón de proyecto@commands_agents (sigue.rb#open_conversation_with_private_note).
  # Si falla (p.ej. inbox no compatible con el contacto), retorna nil y el tracking
  # se crea sin conversation_id — el job lo manejará al ejecutar.
  def open_conversation_with_private_note(contact, inbox_id)
    inbox = @account.inboxes.find_by(id: inbox_id)
    return nil unless inbox

    agent = @current_user || @account.users.first
    return nil unless agent

    contact_inbox = ContactInboxBuilder.new(contact: contact, inbox: inbox).perform

    params = ActionController::Parameters.new(assignee_id: agent.id)
    conversation = ConversationBuilder.new(
      params:         params,
      contact_inbox:  contact_inbox
    ).perform

    Messages::MessageBuilder.new(
      agent,
      conversation,
      { content: '📋 Seguimiento importado via Excel', private: true }
    ).perform

    conversation
  rescue StandardError => e
    Rails.logger.warn "[ContactTrackingImport] No se pudo abrir conversación: #{e.message}"
    nil
  end

  # Busca el contacto; si no existe lo crea con los datos del Excel.
  # Reutiliza DataImport::ContactManager ya presente en Chatwoot.
  def find_or_create_contact(row_data, row_number)
    raw_phone = row_data['contact_phone'].to_s.strip
    name      = row_data['contact_name'].to_s.strip

    # Si contact_phone tiene algo escrito, validar que tenga al menos 10 dígitos
    if raw_phone.present?
      digits = raw_phone.gsub(/\D/, '')
      if digits.length < 10
        add_error(row_number, "El teléfono '#{raw_phone}' en contact_phone está mal escrito (menos de 10 dígitos). Corrígelo o déjalo vacío para usar contact_name.")
        return nil
      end
    end

    phone = normalize_phone(raw_phone)

    if phone.blank? && name.blank?
      add_error(row_number, 'Se requiere contact_phone o contact_name para crear el contacto')
      return nil
    end

    # 1. Buscar por variantes del número (cubre todos los formatos de teléfono)
    contact = find_contact_by_phone_variants(phone) if phone.present?

    # 2. Si no hay teléfono o no se encontró, buscar por nombre exacto
    contact ||= @account.contacts.find_by(name: name) if name.present?

    # 3. Si aún no existe, crear via ContactManager
    unless contact
      manager = DataImport::ContactManager.new(@account)
      contact = manager.find_or_initialize_contact(phone_number: phone, name: name.presence)
    end

    if contact.new_record?
      contact.name = name.presence || phone
      unless contact.save
        add_error(row_number, "No se pudo crear el contacto: #{contact.errors.full_messages.join(', ')}")
        return nil
      end
    end

    contact
  end

  # Busca un contacto existente en la cuenta por cualquier variante del número.
  # Compara por los últimos 10 dígitos, que son el identificador estable
  # independientemente del prefijo (+52, +521, sin código de país, etc.)
  #
  # Ejemplos que mapean al mismo contacto:
  #   3121002203 / 312-100-22-03 / +523121002203 / +5213121002203
  def find_contact_by_phone_variants(normalized_phone)
    return nil if normalized_phone.blank?

    digits = normalized_phone.gsub(/\D/, '')
    return nil if digits.length < 7

    last_10 = digits.last(10)

    @account.contacts
            .where('phone_number LIKE ?', "%#{last_10}")
            .first
  end

  # Normaliza el teléfono a formato E.164.
  # Excel guarda números grandes en notación científica: 5.23123205896E+11
  # También puede venir como float: 523123205896.0
  def normalize_phone(raw)
    phone = raw.to_s.strip.gsub(/[\s\-\(\)]+/, '')
    return nil if phone.blank?

    # Convertir notación científica o float a dígitos limpios
    # Ejemplos: "5.23123205896E+11" → "523123205896"
    #           "523123205896.0"    → "523123205896"
    if phone.gsub(/^\+/, '').match?(/\A[\d.]+([eE][+\-]?\d+)?\z/)
      phone = phone.start_with?('+') ? "+#{phone.sub('+', '').to_f.to_i}" : phone.to_f.to_i.to_s
    end

    # Extraer solo dígitos para trabajar con ellos
    digits = phone.gsub(/\D/, '')
    return nil if digits.length < 7

    # Tomar los últimos 10 dígitos como número local
    last_10 = digits.last(10)

    # Formato canónico México: +521 + 10 dígitos
    "+521#{last_10}"
  end

  # Resuelve inbox_id y conversation_id de forma unificada.
  #
  # Lógica:
  #   1. Si el contacto tiene conversaciones → usa la más reciente:
  #      inbox_id = conversacion.inbox_id  /  conversation_id = conversacion.id
  #   2. Si no tiene conversaciones → inbox_id del Excel o de la plantilla,
  #      conversation_id = nil (el bot la creará al ejecutar)
  def resolve_inbox_and_conversation(contact, template, row_data)
    conversation = contact.conversations
                          .order(status: :asc, last_activity_at: :desc)
                          .first

    if conversation
      return [conversation.inbox_id, conversation.id]
    end

    # Sin conversaciones: resolver inbox desde Excel o plantilla
    inbox_id = nil
    raw = row_data['inbox_id'].to_s.strip
    if raw.present?
      inbox_id = @account.inboxes.find_by(id: raw.to_i)&.id
    end
    inbox_id ||= template.inbox_id.presence

    [inbox_id, nil]
  end

  def parse_datetime(value, timezone = 'UTC')
    return nil if value.blank?

    str = value.to_s.strip

    Time.use_zone(timezone) do
      # Excel guarda fechas como número serial (días desde 30/12/1899).
      # Ejemplo: 46111.583333 = 30/03/2026 14:00
      if str.match?(/\A\d+(\.\d+)?\z/)
        serial       = str.to_f
        date_part    = Date.new(1899, 12, 30) + serial.floor
        time_seconds = ((serial % 1) * 86_400).round
        hours,   rem = time_seconds.divmod(3600)
        minutes, sec = rem.divmod(60)
        return Time.zone.local(date_part.year, date_part.month, date_part.day, hours, minutes, sec)
      end

      return Time.zone.parse(str)
    end
  rescue StandardError
    nil
  end

  # ============================================================
  # Helpers genéricos
  # ============================================================

  def int_or_default(value, default)
    return default if value.blank?

    int = value.to_s.to_i
    int > 0 ? int : default
  end

  def str_or_default(value, default)
    value.to_s.strip.presence || default
  end

  def row_blank?(row_data)
    row_data.values.all?(&:blank?)
  end

  def add_error(row_number, message)
    @results[:errors] << { row: row_number, message: message }
  end
end

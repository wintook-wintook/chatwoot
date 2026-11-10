# Plan-Organizaciones O4 — importar organizaciones de un CSV (Excel › Guardar como CSV UTF-8).
#
# Con la columna «id» se actualiza esa organización; si no, se busca por RFC o nombre y,
# si no existe, se crea. «tipo»: empresa o publico_en_general. «etapa»: prospecto o cliente
# (pasar a cliente queda en la bitácora). «responsable»: correo del usuario. «contactos»:
# correos o teléfonos separados por «;» que se ligan (no se inventan contactos: el que no
# existe se reporta). Lo vacío al actualizar deja lo que ya tenía.
class Organizations::CsvImport
  COLUMNS = %w[id nombre tipo etapa rfc giro sitio_web dominio_correo telefono direccion responsable notas
               contactos].freeze
  KINDS = { 'empresa' => :company, 'company' => :company, 'publico_en_general' => :general_public,
            'público en general' => :general_public, 'publico en general' => :general_public,
            'general_public' => :general_public }.freeze
  STAGES = { 'prospecto' => :prospect, 'prospect' => :prospect, 'cliente' => :customer, 'customer' => :customer }.freeze
  FIELDS = { 'rfc' => :tax_id, 'giro' => :industry, 'sitio_web' => :website, 'dominio_correo' => :email_domain,
             'telefono' => :phone_number, 'direccion' => :address, 'notas' => :notes }.freeze

  # Por RFC o por nombre (sin distinguir mayúsculas); nil si no hay.
  def self.find(account, value)
    text = value.to_s.strip
    return if text.blank?

    account.organizations.find_by(tax_id: text.upcase) || account.organizations.where('LOWER(name) = ?', text.downcase).first
  end

  def initialize(account:, contacts:, user:)
    @account = account
    @contacts = contacts
    @user = user
  end

  def call(table)
    result = { created: 0, updated: 0, errors: [] }
    table.each.with_index(2) do |row, line|
      created = import_row(normalize(row))
      result[created ? :created : :updated] += 1
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      result[:errors] << { line: line, error: e.message }
    end
    result
  end

  private

  def normalize(row)
    row.to_h.transform_keys { |key| key.to_s.strip.downcase.tr(' ', '_') }.transform_values { |v| v.to_s.strip }
  end

  def import_row(row)
    organization = find_organization(row)
    created = organization.new_record?
    Organization.transaction do
      organization.assign_attributes(attributes(row))
      stage = STAGES[row['etapa'].downcase] if row['etapa'].present?
      organization.stage = stage if created && stage
      organization.save!
      organization.change_stage!(stage, @user) if !created && stage
      link_contacts(organization, row['contactos'])
    end
    created
  end

  def find_organization(row)
    if row['id'].present?
      return @account.organizations.find_by(id: row['id']) ||
             raise(ArgumentError, I18n.t('organizations.import.not_found', id: row['id']))
    end

    self.class.find(@account, row['rfc']) || self.class.find(@account, row['nombre']) || @account.organizations.new
  end

  def attributes(row)
    attrs = FIELDS.to_h { |column, field| [field, row[column].presence] }
    attrs[:name] = row['nombre'].presence
    attrs[:kind] = KINDS[row['tipo'].downcase] if row['tipo'].present?
    attrs[:owner_id] = find_owner(row['responsable'])&.id
    attrs.compact
  end

  def find_owner(email)
    return if email.blank?

    @account.users.find_by('LOWER(users.email) = ?', email.downcase) ||
      raise(ArgumentError, I18n.t('organizations.import.owner_not_found', value: email))
  end

  def find_contact(key)
    @contacts.find_by('LOWER(contacts.email) = ?', key.downcase) ||
      @contacts.find_by(phone_number: key.start_with?('+') ? key : "+#{key}") ||
      raise(ArgumentError, I18n.t('organizations.import.contact_not_found', value: key))
  end

  def link_contacts(organization, value)
    value.to_s.split(';').map(&:strip).compact_blank.each do |key|
      contact = find_contact(key)
      next if contact.organization_id == organization.id
      # Uno que ya está en otra no se cambia aquí: «Cambiar de organización» en el contacto.
      raise ArgumentError, I18n.t('organizations.import.contact_elsewhere', value: key) if contact.organization_id

      contact.update!(organization: organization)
    end
  end
end

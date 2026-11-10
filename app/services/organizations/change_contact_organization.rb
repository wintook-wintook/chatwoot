# Plan-Organizaciones — «Cambiar de organización» en la ficha del contacto (solo con esta
# acción se cambia un contacto que ya tiene organización).
#
#   move: true   «estaba en la equivocada»: todo lo suyo en la anterior pasa a la nueva.
#   move: false  «se cambió de empresa»: lo suyo se queda en la anterior; lo vivo pasa al
#                contacto que queda en su lugar (obligatorio: substitute[:contact], otro de la
#                anterior, o substitute[:new_contact], uno nuevo que se crea ahí); lo cerrado
#                se queda con él como historial.
# La nueva puede ser ninguna (to: nil). Queda en la bitácora de las dos.
class Organizations::ChangeContactOrganization
  class Error < StandardError; end

  # Para la ventana: qué tiene en su organización (todo y lo vivo) y quién puede quedar.
  def self.preview(contact)
    organization = contact.organization
    {
      organization: organization.slice(:id, :name),
      counts: Organizations::ContactRecords.new(contact).counts(organization.id),
      candidates: organization.contacts.where.not(id: contact.id).order(:name)
                              .map { |c| c.slice(:id, :name, :email, :phone_number) }
    }
  end

  def initialize(contact:, to:, move:, user:, substitute: {})
    @contact = contact
    @from = contact.organization
    @to = to
    @move = move
    @user = user
    @replacement = substitute[:contact]
    @new_contact = substitute[:new_contact].to_h.symbolize_keys.slice(:name, :email, :phone_number).compact_blank
  end

  def call
    validate!
    Organization.transaction do
      records = Organizations::ContactRecords.new(@contact)
      replacement = @move ? nil : replacement_contact
      counts = records.counts(@from.id)[:all]
      @move ? records.move!(@from.id, @to&.id) : records.hand_over_live!(@from.id, replacement)
      @contact.update!(organization: @to)
      log(counts, replacement)
    end
    @contact
  end

  private

  def validate!
    raise Error, I18n.t('organizations.change.no_organization') if @from.nil?
    raise Error, I18n.t('organizations.change.same') if @to&.id == @from.id

    validate_substitute! unless @move
  end

  def validate_substitute!
    raise Error, I18n.t('organizations.change.replacement_required') if @replacement.nil? && @new_contact[:name].blank?
    return if @replacement.nil? || (@replacement.organization_id == @from.id && @replacement.id != @contact.id)

    raise Error, I18n.t('organizations.change.replacement_invalid')
  end

  def replacement_contact
    @replacement || @contact.account.contacts.create!(@new_contact.merge(organization: @from))
  end

  def log(counts, replacement)
    data = { contact_id: @contact.id, contact_name: @contact.name, moved: @move, counts: counts,
             replacement_id: replacement&.id, replacement_name: replacement&.name }
    @from.events.create!(user: @user, action: 'contact_left', data: data.merge(to: @to&.name))
    @to&.events&.create!(user: @user, action: 'contact_joined', data: data.merge(from: @from.name))
  end
end

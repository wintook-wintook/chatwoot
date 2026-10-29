# Responsable fijo del contacto (ver ContactOwnerAssignment). Lo ve cualquiera
# que vea el contacto; lo cambia quien tiene «Asignar a otra persona».
#
#   GET   /contacts/:contact_id/owner
#   PATCH /contacts/:contact_id/owner  { owner_id }  (vacío = sin responsable fijo)
#
# `missing_inboxes`: bandejas por las que ya escribe el contacto y en las que el
# responsable no está; ahí siguen las reglas normales.
class Api::V1::Accounts::Contacts::OwnersController < Api::V1::Accounts::Contacts::BaseController
  def show
    render json: owner_json
  end

  def update
    return render json: { error: I18n.t('access_roles.reassign_denied') }, status: :forbidden unless access_grant.can?(:reassign)

    @contact.update!(owner_id: params[:owner_id].presence)
    render json: owner_json
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  private

  def owner_json
    owner = @contact.owner
    {
      owner: owner && { id: owner.id, name: owner.name, thumbnail: owner.avatar_url },
      can_edit: access_grant.can?(:reassign),
      missing_inboxes: missing_inboxes(owner)
    }
  end

  def missing_inboxes(owner)
    return [] unless owner

    Current.account.inboxes
           .where(id: @contact.contact_inboxes.select(:inbox_id))
           .where.not(id: InboxMember.where(user_id: owner.id).select(:inbox_id))
           .pluck(:name)
  end
end

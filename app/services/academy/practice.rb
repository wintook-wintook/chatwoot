# frozen_string_literal: true

# Academia Kontrolya — el Cliente de práctica de cada usuario: un contacto a su nombre, sin
# teléfono ni correo (no se le manda nada), para hacer los ejercicios sin tocar clientes reales.
# Queda marcado en additional_attributes['academy_practice_user_id'] y el usuario es su
# responsable fijo (así lo ve aunque su rol sea «Solo lo suyo»).
#
#   practice = Academy::Practice.new(account, user)
#   practice.contact / practice.case   → el suyo (o nil)
#   practice.create!                   → lo crea si no tiene
#   practice.destroy!                  → borra el contacto y lo que se hizo con él
class Academy::Practice
  MARK = 'academy_practice_user_id'

  def self.scope(account) = account.contacts.where("contacts.additional_attributes ->> '#{MARK}' IS NOT NULL")

  def initialize(account, user)
    @account = account
    @user = user
  end

  def contact
    @contact ||= self.class.scope(@account).find_by("contacts.additional_attributes ->> '#{MARK}' = ?", @user.id.to_s)
  end

  # El caso de práctica: el más reciente del Cliente de práctica.
  def case
    return nil unless contact

    @account.case_tickets.where(contact_id: contact.id).order(created_at: :desc).first
  end

  def create!
    contact || (@contact = @account.contacts.create!(
      name: "Cliente de práctica · #{@user.name.to_s.split.first || @user.id}",
      owner_id: @user.id,
      additional_attributes: { MARK => @user.id.to_s, 'description' => 'Contacto de práctica de la Academia. Se puede borrar.' }
    ))
  end

  # Los casos (con sus tareas y citas) y la organización si solo la usaba él.
  def destroy!
    return false unless contact

    organization = contact.organization
    ActiveRecord::Base.transaction do
      @account.case_tickets.where(contact_id: contact.id).find_each(&:destroy!)
      contact.destroy!
      organization.destroy! if organization && organization.contacts.reload.none?
    end
    @contact = nil
    true
  end
end

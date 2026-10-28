# prospeccion V7b — el correo del contacto rebotó (no existe, buzón cerrado…). Es del CORREO,
# no del contacto: sus otros canales siguen. Se borra solo si le cambian el correo.
# email_bounce_reason: «5.1.1 smtp; 550-5.1.1 The email account … does not exist».
class AddEmailBouncedToContacts < ActiveRecord::Migration[7.0]
  def change
    add_column :contacts, :email_bounced_at, :datetime
    add_column :contacts, :email_bounce_reason, :string
  end
end

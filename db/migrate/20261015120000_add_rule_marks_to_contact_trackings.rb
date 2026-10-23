# proyecto@contact_tracking — cuándo una regla de palabra clave marcó el seguimiento como
# Interesado o Agendó. Los indicadores Interesados/Agendaron de campañas y del overview
# cuentan solo por estas marcas (no por la intención que adivina la IA).
class AddRuleMarksToContactTrackings < ActiveRecord::Migration[7.0]
  def change
    add_column :contact_trackings, :interested_at, :datetime
    add_column :contact_trackings, :booked_at, :datetime
  end
end

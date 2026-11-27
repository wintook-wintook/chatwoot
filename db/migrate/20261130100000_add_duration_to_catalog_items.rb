# Catálogo — cuánto dura un servicio (minutos). Lo usa «Atención a clientes» › Citas de servicio
# (Motor2::Skills::Appointments): la cita ocupa en la agenda la suma de lo que dura cada servicio que pidió.
class AddDurationToCatalogItems < ActiveRecord::Migration[7.0]
  def change
    add_column :catalog_items, :duration_minutes, :integer
  end
end

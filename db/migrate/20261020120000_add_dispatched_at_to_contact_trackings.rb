# proyecto@automatizacion_campanas — Fase 2 (docs/campanas_agentes_ia_capacidad_plan.md §13):
# cuándo el despachador (TrackingDispatch::DispatchJob) tomó el seguimiento para enviarlo.
# Es la marca de quién lo tiene: el envío solo procede si sigue siendo la misma, y uno que
# lleva demasiado tiempo tomado se recupera.
class AddDispatchedAtToContactTrackings < ActiveRecord::Migration[7.0]
  def change
    add_column :contact_trackings, :dispatched_at, :datetime
    add_index :contact_trackings, :dispatched_at, where: "status = 'active'", name: 'index_contact_trackings_dispatched'
  end
end

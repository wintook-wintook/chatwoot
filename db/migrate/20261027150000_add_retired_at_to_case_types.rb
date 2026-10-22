# @tickets_cases — cambiar de clase un tipo con casos: el tipo de antes se queda con
# sus casos tal cual (clase, etapas, datos, métricas) y se RETIRA: ya no se usa para
# crear casos nuevos; el tipo nuevo de la otra clase toma su lugar.
class AddRetiredAtToCaseTypes < ActiveRecord::Migration[7.0]
  def change
    add_column :case_types, :retired_at, :datetime
  end
end

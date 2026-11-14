# Academia Kontrolya (F1) — el avance de cada usuario por módulo y paso (lección o ejercicio).
# Un renglón por usuario + módulo + paso. Los módulos y sus pasos viven en config/academy/modules.yml.
class CreateAcademyProgresses < ActiveRecord::Migration[7.0]
  def change
    create_table :academy_progresses do |t|
      t.references :account, null: false, index: false
      t.references :user, null: false, index: false
      t.string :module_key, null: false
      t.string :step_key, null: false
      t.datetime :started_at # «Hazlo»: desde aquí cuenta lo que haga (no vale lo de antes)
      t.datetime :completed_at
      t.integer :attempts, null: false, default: 0 # veces que pulsó «Revisar»
      t.string :evidence_type # el registro que probó que lo hizo (p. ej. CaseTicket 12)
      t.bigint :evidence_id
      t.timestamps
    end
    add_index :academy_progresses, %i[account_id user_id module_key step_key], unique: true, name: 'index_academy_progress_unique'
  end
end

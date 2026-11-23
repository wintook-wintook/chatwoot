# frozen_string_literal: true

# Agenda: participantes de una tarea agendada (CaseMeeting). Además del responsable (organizer_id), otros usuarios del
# equipo la ven en su Agenda, «Mi día», Dali y (visitas) «Mi ruta»; reciben aviso al agregarlos, si cambia la hora o se
# cancela, y el recordatorio antes de empezar (participants_reminded_at). Solo el responsable la concluye.
#   status: invited | declined («No puedo ir», con su nota)
class CaseMeetingParticipants < ActiveRecord::Migration[7.0]
  def change
    create_table :case_meeting_participants do |t|
      t.references :account, null: false, foreign_key: true
      t.references :case_meeting, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :status, null: false, default: 'invited'
      t.string :note
      t.datetime :responded_at
      t.timestamps
    end
    add_index :case_meeting_participants, %i[case_meeting_id user_id], unique: true, name: 'index_meeting_participants_on_meeting_and_user'
    add_column :case_meetings, :participants_reminded_at, :datetime
  end
end

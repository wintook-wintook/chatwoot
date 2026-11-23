# frozen_string_literal: true

# Dali — «agenda con Beto»: los participantes de la tarea agendada que propone (otros del equipo, sin el usuario,
# que ya es el responsable). Los suma al payload (participant_ids) y sus nombres a las etiquetas de la tarjeta.
module Assistant::MeetingParticipants
  module_function

  def add(account, user, args, payload, labels)
    ids = Array(args['participant_ids']).map(&:to_i)
    people = ids.empty? ? [] : account.users.where(id: ids).where.not(id: user.id).to_a
    return [payload, labels] if people.empty?

    [payload.merge('participant_ids' => people.map(&:id)), labels.merge('participants' => people.map(&:name).join(', '))]
  end
end

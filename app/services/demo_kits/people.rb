# frozen_string_literal: true

# Kits de demo — las personas en la configuración de un agente (user_id, appointment_user_ids, handoff_user_id… en
# cualquier nivel): al exportar se cambian por «lugares» (p1, p2) y al importar por quien se eligió. Con drop: true se
# quitan los ids que no existen en otra cuenta (equipos, tipos de caso, eventos, servicio por omisión).
module DemoKits::People
  PERSON_KEY = /(\A|_)user_ids?\z/
  DROP_KEY = /(\A|_)(team_id|team_ids|case_type_id|event_id|default_service_id)\z/

  module_function

  def map(value, key = nil, drop: false, &)
    return map_hash(value, drop, &) if value.is_a?(Hash)
    return map_list(value, key, drop, &) if value.is_a?(Array)

    person?(key) ? yield(value) : value
  end

  def map_list(list, key, drop, &)
    person?(key) ? list.filter_map(&) : list.map { |v| map(v, drop: drop, &) }
  end

  def map_hash(hash, drop, &)
    hash.each_with_object({}) do |(k, v), out|
      out[k] = map(v, k.to_s, drop: drop, &) unless drop && k.to_s.match?(DROP_KEY)
    end
  end

  def person?(key) = key.to_s.match?(PERSON_KEY)
end

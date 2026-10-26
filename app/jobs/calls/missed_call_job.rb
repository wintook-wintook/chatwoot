# frozen_string_literal: true

# diag/llamadas_whatsapp (F8) — las acciones de una llamada perdida (Calls::MissedCallService).
# Lo encola Call al pasar a un estado final sin agente; el servicio se asegura de correr una vez.
class Calls::MissedCallJob < ApplicationJob
  queue_as :default

  def perform(call_id)
    call = Call.find_by(id: call_id)
    Calls::MissedCallService.new(call: call).perform if call
  end
end

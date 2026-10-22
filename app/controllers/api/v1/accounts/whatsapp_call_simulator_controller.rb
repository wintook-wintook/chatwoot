# frozen_string_literal: true

# ================================================================================
# diag/llamadas_whatsapp (F4) — LO QUE HACE EL «CLIENTE SIMULADO»
# ================================================================================
# Solo con la Meta simulada encendida (WHATSAPP_CALLS_SIMULATOR=true, development);
# si no, 404. Solo administradores. Cada acción arma el MISMO webhook que mandaría Meta
# y lo encola en Webhooks::WhatsappCallEventsJob: se prueba el camino real.
#
#   GET  inboxes                                     bandejas con llamadas activadas
#   GET  signals    { inbox_id, wa_id }              lo que el negocio le mandó (y se vacía)
#   POST call       { inbox_id, wa_id, name, sdp_offer }   el cliente llama
#   POST answer     { inbox_id, call_id, sdp_answer }      contesta la llamada del negocio
#   POST hangup     { inbox_id, call_id, duration }        cuelga
#   POST permission { inbox_id, wa_id, wamid, accept }     responde «Permitir llamadas»
# ================================================================================
class Api::V1::Accounts::WhatsappCallSimulatorController < Api::V1::Accounts::BaseController
  before_action :ensure_enabled, :ensure_administrator
  before_action :set_channel, except: :inboxes

  def inboxes
    bandejas = Current.account.inboxes.where(channel_type: 'Channel::Whatsapp').includes(:channel)
                      .select { |inbox| inbox.channel.voice_enabled? }
    render json: bandejas.map { |inbox| { id: inbox.id, name: inbox.name, phone_number: inbox.channel.phone_number } }
  end

  def signals
    render json: simulator.take_signals(wa_id)
  end

  def call
    call_id = "wacid.sim.#{SecureRandom.hex(8)}"
    simulator.remember_call(call_id, wa_id)
    deliver('calls', { calls: [{ id: call_id, from: wa_id, event: 'connect', timestamp: Time.current.to_i.to_s,
                                 session: { sdp_type: 'offer', sdp: params.require(:sdp_offer) } }],
                       contacts: [{ wa_id: wa_id, profile: { name: params[:name].presence || "+#{wa_id}" } }] })
    render json: { call_id: call_id }
  end

  # Como Meta: primero el connect con el answer (túnel listo) y luego ACCEPTED (contestó).
  def answer
    deliver('calls', { calls: [{ id: params[:call_id], event: 'connect',
                                 session: { sdp_type: 'answer', sdp: params.require(:sdp_answer) } }] })
    deliver('calls', { statuses: [{ id: params[:call_id], type: 'call', status: 'ACCEPTED', timestamp: Time.current.to_i.to_s }] },
            wait: 1.second)
    head :ok
  end

  def hangup
    deliver('calls', { calls: [{ id: params[:call_id], event: 'terminate', duration: params[:duration].to_i,
                                 terminate_reason: 'completed' }] })
    head :ok
  end

  def permission
    acepta = ActiveModel::Type::Boolean.new.cast(params[:accept])
    simulator.grant_permission!(wa_id) if acepta
    deliver('messages', { messages: [{ from: wa_id, id: "wamid.sim.#{SecureRandom.hex(6)}", type: 'interactive',
                                       context: { id: params[:wamid] },
                                       interactive: { type: 'call_permission_reply',
                                                      call_permission_reply: { response: acepta ? 'accept' : 'reject',
                                                                               is_permanent: false } } }] })
    head :ok
  end

  private

  def ensure_enabled
    head :not_found unless Whatsapp::Providers::CallsSimulator.enabled?
  end

  def ensure_administrator
    head :unauthorized unless Current.account_user&.administrator?
  end

  def set_channel
    inbox = Current.account.inboxes.find(params[:inbox_id])
    @channel = inbox.channel
    head :unprocessable_entity unless @channel.is_a?(Channel::Whatsapp) && @channel.voice_enabled?
  end

  def simulator
    @simulator ||= Whatsapp::Providers::CallsSimulator.new(whatsapp_channel: @channel)
  end

  def wa_id
    params.require(:wa_id).to_s.delete('+')
  end

  def deliver(field, value, wait: nil)
    payload = simulator.webhook(field, value).deep_stringify_keys
    job = wait ? Webhooks::WhatsappCallEventsJob.set(wait: wait) : Webhooks::WhatsappCallEventsJob
    job.perform_later(payload)
  end
end

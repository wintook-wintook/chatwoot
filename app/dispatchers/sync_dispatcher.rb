class SyncDispatcher < BaseDispatcher
  def dispatch(event_name, timestamp, data)
    event_object = Events::Base.new(event_name, timestamp, data)
    # feat/chat_interno (plan v2): en «Interno» solo tiempo real, sin bots.
    if InternalChannel::Events.internal?(data)
      return InternalChannel::Events.publish_internal(listeners, InternalChannel::Events::SYNC_LISTENERS,
                                                      event_object.method_name, event_object)
    end

    publish(event_object.method_name, event_object)
  end

  def listeners
    [ActionCableListener.instance, AgentBotListener.instance]
  end
end

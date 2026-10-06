module PushDataHelper
  extend ActiveSupport::Concern

  def push_event_data
    Conversations::EventDataPresenter.new(self).push_data
  end

  def lock_event_data
    Conversations::EventDataPresenter.new(self).lock_data
  end

  # webhook_data ya no es un alias de push_data: el payload de webhook lleva account_id
  # y el de websocket no. Ver Conversations::EventDataPresenter#webhook_data.
  def webhook_data
    Conversations::EventDataPresenter.new(self).webhook_data
  end
end

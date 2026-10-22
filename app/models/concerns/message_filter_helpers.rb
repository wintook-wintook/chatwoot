module MessageFilterHelpers
  extend ActiveSupport::Concern

  def reportable?
    incoming? || outgoing?
  end

  # diag/llamadas_whatsapp: la burbuja de una llamada no va a bots ni webhooks externos
  def webhook_sendable?
    (incoming? || outgoing? || template?) && !voice_call?
  end

  def slack_hook_sendable?
    incoming? || outgoing? || template?
  end

  def notifiable?
    incoming? || outgoing?
  end

  def conversation_transcriptable?
    incoming? || outgoing?
  end

  def email_reply_summarizable?
    incoming? || outgoing? || input_csat?
  end

  def instagram_story_mention?
    inbox.instagram? && try(:content_attributes)[:image_type] == 'story_mention'
  end

  def instagram?
    inbox.instagram?
  end
end

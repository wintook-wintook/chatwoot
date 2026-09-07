class Channels::Instagram::RefreshOauthTokenJob < ApplicationJob
  queue_as :low

  def perform(channel)
    return if channel.blank?

    # Un token ya vencido no se puede renovar: Meta solo acepta el refresh dentro de los
    # 60 días. Marcarlo directamente evita gastar llamadas en algo que no puede salir bien.
    return prompt_reauthorization(channel, 'token already expired') if channel.token_expired?

    refresh(channel)
  end

  private

  def refresh(channel)
    response = ::Instagram::OauthService.new.refresh_long_lived_token(channel.access_token)

    channel.update!(
      access_token: response[:access_token],
      expires_at: expires_at_from(response, channel)
    )
    # Si el canal estaba marcado como caducado, esto limpia el aviso de reautorización.
    channel.reauthorized!
  rescue ::Instagram::OauthService::OauthError => e
    Rails.logger.warn("[Instagram] token refresh failed for channel #{channel.id}: #{e.message}")
    prompt_reauthorization(channel, e.message)
  end

  def expires_at_from(response, channel)
    expires_in = response[:expires_in].to_i
    return channel.expires_at if expires_in.zero?

    Time.current + expires_in.seconds
  end

  # El administrador tiene que volver a autorizar: se le avisa por correo y queda el
  # banner en el inbox.
  def prompt_reauthorization(channel, reason)
    Rails.logger.warn("[Instagram] reauthorization required for channel #{channel.id}: #{reason}")
    channel.prompt_reauthorization!
  end
end

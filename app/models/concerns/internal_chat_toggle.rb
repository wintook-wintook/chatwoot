# frozen_string_literal: true

# feat/chat_interno — ENCENDER / APAGAR EL CHAT INTERNO DE UNA CUENTA
# Encendido por omisión (decisión D6). No usa feature_flags: con 63 banderas el `bigint`
# ya está lleno y la 64 se desbordaría (Chatwoot 4.19 lo resolvió con otra columna). Solo se
# guarda la excepción: custom_attributes['internal_chat_disabled'] = true. Lo cambia el
# super admin con la casilla «Chat interno» de la cuenta.
module InternalChatToggle
  extend ActiveSupport::Concern

  DISABLED_KEY = 'internal_chat_disabled'

  def internal_chat_enabled
    custom_attributes.to_h[DISABLED_KEY] != true
  end
  alias internal_chat_enabled? internal_chat_enabled

  def internal_chat_enabled=(value)
    enabled = ActiveModel::Type::Boolean.new.cast(value)
    attrs = custom_attributes.to_h.except(DISABLED_KEY)
    self.custom_attributes = enabled ? attrs : attrs.merge(DISABLED_KEY => true)
  end
end

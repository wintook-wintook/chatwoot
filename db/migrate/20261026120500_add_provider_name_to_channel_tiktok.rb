# Paridad con Chatwoot 4.19 (20260831000000_add_provider_name_to_social_channels): el usuario de
# TikTok con el que se conectó la bandeja, para saber qué cuenta es sin depender del nombre del
# inbox (que el usuario puede cambiar). Allá la migración también toca Instagram y Facebook;
# aquí solo TikTok.
class AddProviderNameToChannelTiktok < ActiveRecord::Migration[7.0]
  def change
    add_column :channel_tiktok, :provider_name, :string
  end
end

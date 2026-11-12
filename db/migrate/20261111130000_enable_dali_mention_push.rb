# Dali en el teléfono avisa también cuando te mencionan: a quien ya activó los avisos desde
# Dali se le enciende el push de menciones (los nuevos lo traen al activarlos).
class EnableDaliMentionPush < ActiveRecord::Migration[7.0]
  def up
    user_ids = NotificationSubscription.where("subscription_attributes->>'dali' IS NOT NULL").distinct.pluck(:user_id)
    NotificationSetting.where(user_id: user_ids).find_each do |setting|
      setting.push_conversation_mention = true
      setting.save!
    end
  end

  def down; end
end

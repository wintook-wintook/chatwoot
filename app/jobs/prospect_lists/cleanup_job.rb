# frozen_string_literal: true

# Cada día: de las listas frías cuya campaña ya terminó (o que no tiene seguimientos vivos) hace más de cleanup_days,
# borra los contactos que siguen en cuarentena (nunca contestaron), con sus conversaciones. Los que se dieron de baja o
# rebotaron quedan en EmailSuppression para no volver a cargarlos.
class ProspectLists::CleanupJob < ApplicationJob
  queue_as :scheduled_jobs
  LIVE = %w[pending scheduled active paused].freeze

  def perform
    ProspectList.where(cleaned_at: nil).find_each do |list|
      next unless due?(list)

      clean(list)
    rescue StandardError => e
      Rails.logger.error("[ProspectLists::CleanupJob] lista #{list.id}: #{e.class}: #{e.message}")
    end
  end

  private

  # Ya no hay a quién escribirle de esta lista y pasaron sus días.
  def due?(list)
    campaign = list.tracking_campaign
    return list.created_at < list.cleanup_days.days.ago if campaign.nil?

    finished = campaign.ends_at || ContactTracking.where(tracking_campaign_id: campaign.id).maximum(:updated_at) || campaign.updated_at
    !ContactTracking.exists?(tracking_campaign_id: campaign.id, contact_id: list.contacts.select(:id), status: LIVE) &&
      finished < list.cleanup_days.days.ago
  end

  def clean(list)
    removed = 0
    list.contacts.where(list_quarantine: true).find_each do |contact|
      suppress(contact)
      contact.destroy!
      removed += 1
    end
    list.update!(cleaned_at: Time.current, stats: list.stats.to_h.merge('removed' => removed))
  end

  def suppress(contact)
    EmailSuppression.add!(contact.account, contact.email, 'opted_out') if contact.opted_out?
    EmailSuppression.add!(contact.account, contact.email, 'bounced') if contact.email_bounced?
  end
end

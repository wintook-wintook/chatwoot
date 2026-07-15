# frozen_string_literal: true

# ================================================================================
# proyecto@bulk_tracking_assign / @campanas_vendedor
# ================================================================================
# Job: ContactTrackings::BulkAssignJob
# Descripción: Procesa en background la asignación masiva de una TrackingTemplate
#              a los contactos de una campaña. Lo encola
#              ContactTrackings::BulkAssignService#call tras crear la TrackingCampaign,
#              para no bloquear el request (creaba conversaciones + notas por contacto).
# Queue: medium (operación por lote disparada por el usuario)
# ================================================================================

module ContactTrackings
  class BulkAssignJob < ApplicationJob
    queue_as :medium

    def perform(args)
      args = args.symbolize_keys
      account = Account.find_by(id: args[:account_id])
      return unless account

      campaign = account.tracking_campaigns.find_by(id: args[:campaign_id])
      return unless campaign

      result = build_service(account, campaign, args).process!

      Rails.logger.info(
        "[BulkAssignJob] Campaña #{campaign.id} procesada: " \
        "inserted=#{result[:inserted]} skipped=#{result[:skipped]} errors=#{result[:errors].size}"
      )
    end

    private

    def build_service(account, campaign, args)
      current_user = args[:current_user_id] && User.find_by(id: args[:current_user_id])

      ContactTrackings::BulkAssignService.new(
        account: account,
        current_user: current_user,
        filter_payload: args[:filter_payload],
        template_id: args[:template_id],
        scheduled_for: parse_time(args[:scheduled_for]),
        campaign_name: campaign.name,
        excluded_contact_ids: args[:excluded_contact_ids],
        skip_active: args[:skip_active],
        campaign: campaign
      )
    end

    def parse_time(value)
      return value if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)

      Time.zone.parse(value.to_s)
    end
  end
end

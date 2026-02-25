# frozen_string_literal: true

# ================================================================================
# proyecto@contact_tracking
# ================================================================================
# Job: CleanupJob
# Descripción: Limpia trackings antiguos completados o cancelados
# ================================================================================

module ContactTrackings
    class CleanupJob < ApplicationJob
      queue_as :low_priority
  
      def perform
        Rails.logger.info "[ContactTracking] 🧹 Iniciando limpieza de trackings antiguos..."
        
        # Eliminar trackings completados o cancelados de más de 90 días
        old_trackings = ContactTracking
          .where(status: %w[completed cancelled])
          .where('updated_at < ?', 90.days.ago)
        
        count = old_trackings.count
        
        if count > 0
          old_trackings.delete_all
          Rails.logger.info "[ContactTracking] ✅ Eliminados #{count} trackings antiguos"
        else
          Rails.logger.info "[ContactTracking] ✅ No hay trackings para limpiar"
        end
      end
    end
  end
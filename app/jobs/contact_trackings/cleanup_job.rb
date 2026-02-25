# frozen_string_literal: true

# ================================================================================
# proyecto@contact_tracking
# /home/chatwoot/chatwoot/app/jobs/contact_trackings/cleanup_job.rb
# ================================================================================
# Job: CleanupJob
# Descripción: Job de limpieza de tracking antiguos completados, cancelados o fallidos
#              para mantener la base de datos optimizada
# Funcionalidades:
#   - Elimina trackings completados con más de 90 días
#   - Elimina trackings cancelados con más de 90 días
#   - Elimina trackings fallidos con más de 90 días
#   - Logging de estadísticas de limpieza
# Schedule: Diario a las 2 AM (0 2 * * *)
# Queue: low_priority
# Retención: 90 días (configurable)
# Autor: Chatwoot Follow-up AI Bot
# Versión: 1.0.0
# ================================================================================

module ContactTrackings
    class CleanupJob < ApplicationJob
      queue_as :low_priority
  
      # ==========================================================================
      # Constants
      # ==========================================================================
      RETENTION_DAYS = 90
  
      # ==========================================================================
      # Método Principal: Limpiar trackings antiguos
      # ==========================================================================
      def perform
        cutoff_date = RETENTION_DAYS.days.ago
  
        # Eliminar trackings completados antiguos
        completed_deleted = ContactTracking.completed
                                          .where('updated_at < ?', cutoff_date)
                                          .delete_all
  
        # Eliminar trackings cancelados antiguos
        cancelled_deleted = ContactTracking.cancelled
                                          .where('updated_at < ?', cutoff_date)
                                          .delete_all
  
        # Eliminar trackings fallidos antiguos
        failed_deleted = ContactTracking.failed
                                       .where('updated_at < ?', cutoff_date)
                                       .delete_all
  
        total_deleted = completed_deleted + cancelled_deleted + failed_deleted
  
        Rails.logger.info(
          "proyecto@contact_tracking - CleanupJob: Deleted #{total_deleted} old trackings " \
          "(completed: #{completed_deleted}, cancelled: #{cancelled_deleted}, failed: #{failed_deleted})"
        )
      end
    end
  end
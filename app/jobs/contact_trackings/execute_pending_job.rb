# frozen_string_literal: true

# ================================================================================
# proyecto@contact_tracking
# /home/chatwoot/chatwoot/app/jobs/contact_trackings/execute_pending_job.rb
# ================================================================================
# Job: ExecutePendingJob
# Descripción: Job ejecutado por cron cada 5 minutos para procesar
#              seguimientos pendientes que deben ejecutarse
# Funcionalidades:
#   - Busca tracking con scheduled_for <= now
#   - Filtra por estados activos (pending, scheduled, active)
#   - Queue job individual por cada tracking
#   - Logging de ejecución
# Schedule: Cada 5 minutos (*/5 * * * *)
# Queue: scheduled_jobs
# Autor: Chatwoot Follow-up AI Bot
# Versión: 1.0.0
# ================================================================================

module ContactTrackings
    class ExecutePendingJob < ApplicationJob
      queue_as :scheduled_jobs
  
      # ==========================================================================
      # Método Principal: Ejecutar trackings pendientes
      # ==========================================================================
      def perform
        # Encontrar todos los tracking que deben ejecutarse
        due_trackings = ContactTracking.due_for_execution
  
        Rails.logger.info("proyecto@contact_tracking - ExecutePendingJob: Found #{due_trackings.count} trackings to execute")
  
        executed_count = 0
        failed_count = 0
  
        due_trackings.find_each do |tracking|
          begin
            # Queue el job individual para cada tracking
            ContactTrackingJob.perform_later(tracking.id)
            executed_count += 1
          rescue StandardError => e
            failed_count += 1
            Rails.logger.error("proyecto@contact_tracking - Failed to queue tracking ##{tracking.id}: #{e.message}")
          end
        end
  
        Rails.logger.info("proyecto@contact_tracking - ExecutePendingJob completed: #{executed_count} queued, #{failed_count} failed")
      end
    end
  end
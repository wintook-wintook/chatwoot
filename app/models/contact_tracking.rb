# frozen_string_literal: true

# ================================================================================
# proyecto@contact_tracking
# ================================================================================
# Modelo: ContactTracking
# Descripción: Modelo principal para gestión de seguimientos automáticos
#              Maneja el ciclo de vida completo: creación, ejecución, 
#              reprogramación, pausas y cancelaciones
# Funcionalidades:
#   - Validaciones de campos requeridos y formatos
#   - 7 estados posibles (pending, scheduled, active, paused, completed, cancelled, failed)
#   - Scopes para consultas optimizadas
#   - Métodos para control del ciclo de vida
#   - Callbacks para automatización de jobs
#   - Soporte para plantillas WhatsApp por intento
#   - Intervalos flexibles (minutos, horas, días)
# Autor: Chatwoot Follow-up AI Bot
# Versión: 2.0.0 (con WhatsApp Templates)
# ================================================================================

# == Schema Information
#
# Table name: contact_trackings
#
#  id                         :bigint           not null, primary key
#  ai_context                 :text
#  appointment_at             :datetime
#  attempt_count              :integer          default(0), not null
#  calendar_event_duration    :integer          default(30)
#  calendar_integration_ids   :jsonb            not null
#  complementary_prompt       :text
#  interval_days              :integer
#  keyword_actions            :jsonb            not null
#  last_attempt_at            :datetime
#  last_error                 :string
#  last_intent                :string
#  last_message_sent          :text
#  last_sentiment_analysis    :jsonb
#  max_attempts               :integer          default(3), not null
#  objective                  :string           not null
#  outcome                    :string
#  paused_at                  :datetime
#  response_adjustments_count :integer          default(0), not null
#  retry_interval_unit        :string           default("minutes")
#  retry_interval_value       :integer          default(30)
#  scheduled_for              :datetime         not null
#  status                     :string           default("pending"), not null
#  whatsapp_templates         :json
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  account_id                 :bigint           not null
#  appointment_calendar_id    :bigint
#  appointment_event_id       :string
#  contact_id                 :bigint           not null
#  conversation_id            :bigint
#  inbox_id                   :bigint           not null
#  quote_id                   :integer
#  tracking_template_id       :integer
#
# Indexes
#
#  index_contact_trackings_on_account_id                    (account_id)
#  index_contact_trackings_on_appointment_at                (appointment_at)
#  index_contact_trackings_on_contact_id                    (contact_id)
#  index_contact_trackings_on_conversation_id               (conversation_id)
#  index_contact_trackings_on_conversation_id_and_inbox_id  (conversation_id,inbox_id)
#  index_contact_trackings_on_inbox_id                      (inbox_id)
#  index_contact_trackings_on_last_intent                   (last_intent)
#  index_contact_trackings_on_scheduled_for                 (scheduled_for)
#  index_contact_trackings_on_sentiment                     (((last_sentiment_analysis ->> 'sentiment'::text)))
#  index_contact_trackings_on_status                        (status)
#  index_contact_trackings_on_status_and_scheduled_for      (status,scheduled_for)
#  index_unique_active_tracking_per_contact_inbox           (contact_id,inbox_id,status) UNIQUE WHERE ((status)::text = ANY ((ARRAY['pending'::character varying, 'scheduled'::character varying, 'active'::character varying, 'paused'::character varying])::text[]))
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (inbox_id => inboxes.id)
#

class ContactTracking < ApplicationRecord
  # ==============================================================================
  # Associations
  # ==============================================================================
  belongs_to :contact
  belongs_to :conversation, optional: true
  belongs_to :inbox
  belongs_to :account
  belongs_to :tracking_template, optional: true

  # ==============================================================================
  # Serializers - Para campos JSON
  # ==============================================================================
  # PostgreSQL maneja JSON nativamente, no necesitamos serialize
  # El campo whatsapp_templates se serializará automáticamente como Array
  # serialize :whatsapp_templates, JSON  # ❌ NO NECESARIO en PostgreSQL

  # ==============================================================================
  # Enums - Estados posibles del seguimiento
  # ==============================================================================
  enum status: {
    pending: 'pending',       # Creado, esperando primera ejecución
    scheduled: 'scheduled',   # Programado para próximo intento
    active: 'active',         # En proceso de ejecución
    paused: 'paused',         # Pausado manualmente
    completed: 'completed',   # Completado exitosamente
    cancelled: 'cancelled',   # Cancelado manualmente
    failed: 'failed'          # Falló en ejecución
  }

  # ==============================================================================
  # Validations
  # ==============================================================================
  validates :objective, presence: true, length: { minimum: 5, maximum: 500 }
  validates :scheduled_for, presence: true
  validates :max_attempts, presence: true, 
            numericality: { greater_than: 0, less_than_or_equal_to: 10 }
  validates :attempt_count, 
            numericality: { greater_than_or_equal_to: 0 }
  validates :interval_days, 
            numericality: { greater_than_or_equal_to: 1 }, 
            allow_nil: true
  
  # ⭐ NUEVO: Validaciones para retry_interval
  validates :retry_interval_value,
            numericality: { greater_than_or_equal_to: 1 },
            allow_nil: true
  validates :retry_interval_unit,
            inclusion: { in: %w[minutes hours days] },
            allow_nil: true
  
  validate :scheduled_for_cannot_be_in_past, on: :create
  validate :conversation_belongs_to_inbox, if: :conversation_id?
  validate :only_one_active_tracking_per_contact_and_inbox, on: :create
  validate :all_templates_must_be_present, if: :using_templates?

  # ==============================================================================
  # Scopes - Consultas optimizadas
  # ==============================================================================
  scope :active_or_scheduled, -> { where(status: %w[active scheduled pending]) }
  scope :due_for_execution, -> { where('scheduled_for <= ?', Time.current).active_or_scheduled }
  scope :by_inbox, ->(inbox_id) { where(inbox_id: inbox_id) }
  scope :by_conversation, ->(conversation_id) { where(conversation_id: conversation_id) }
  scope :recent, -> { order(created_at: :desc) }
  scope :upcoming, -> { where('scheduled_for > ?', Time.current).order(scheduled_for: :asc) }

  # ==============================================================================
  # Callbacks
  # ==============================================================================
  before_save :ensure_account_id
  before_save :ensure_whatsapp_templates_array  # ⭐ NUEVO
  after_create :schedule_job, if: :pending?
  after_update :reschedule_job_if_needed  # ⭐ NUEVO: Reprograma job si cambió scheduled_for

  # ==============================================================================
  # Instance Methods - Control de estado
  # ==============================================================================
  
  # Verifica si el seguimiento puede ejecutarse
  def can_execute?
    (pending? || scheduled? || active?) && scheduled_for <= Time.current
  end

  # Verifica si el seguimiento puede pausarse
  def can_pause?
    pending? || active? || scheduled?
  end

  # Verifica si el seguimiento puede reanudarse
  def can_resume?
    paused?
  end

  # Verifica si el seguimiento puede cancelarse
  def can_cancel?
    !completed? && !cancelled?
  end

  # Calcula intentos restantes
  def attempts_remaining
    max_attempts - attempt_count
  end

  # ==============================================================================
  # Instance Methods - Plantillas WhatsApp (⭐ NUEVO)
  # ==============================================================================
  
  # Obtiene la plantilla correspondiente al intento actual
  # @return [String, nil] Nombre de la plantilla o nil
  # @example
  #   tracking.whatsapp_templates = ["template_1", "template_2", "template_3"]
  #   tracking.attempt_count = 0
  #   tracking.current_template  # => "template_1"
  #   tracking.attempt_count = 1
  #   tracking.current_template  # => "template_2"
  def current_template
    return nil unless whatsapp_templates.is_a?(Array)
    return nil if attempt_count >= whatsapp_templates.length
    
    template_name = whatsapp_templates[attempt_count]
    # Retornar nil si es string vacío o nil
    template_name.presence
  end
  
  # Verifica si debe usar plantilla para el intento actual
  # @return [Boolean]
  # @example
  #   tracking.whatsapp_templates = ["template_1"]
  #   tracking.attempt_count = 0
  #   tracking.use_template_for_current_attempt?  # => true
  #   tracking.attempt_count = 1
  #   tracking.use_template_for_current_attempt?  # => false (fuera de rango)
  def use_template_for_current_attempt?
    current_template.present?
  end

  # ⭐ MODO REINTENTO AUTOMÁTICO - Usando ai_context para marcar estado
  def auto_retry_mode?
    ai_context.to_s.include?('[AUTO_RETRY_MODE]')
  end

  def enable_auto_retry_mode!
    return if auto_retry_mode?
    self.ai_context = "[AUTO_RETRY_MODE]\n#{ai_context}"
  end

  def disable_auto_retry_mode!
    return unless auto_retry_mode?
    self.ai_context = ai_context.to_s.gsub('[AUTO_RETRY_MODE]', '').strip
  end

  # ⭐ NUEVO: Contar plantillas WhatsApp configuradas
  def whatsapp_templates_count
    return max_attempts unless whatsapp_templates.is_a?(Array)

    # Contar plantillas no vacías, o usar max_attempts si no hay plantillas
    count = whatsapp_templates.count { |t| t.present? }
    count > 0 ? count : max_attempts
  end

  # ==============================================================================
  # Instance Methods - Cálculo de próxima ejecución (⭐ ACTUALIZADO)
  # ==============================================================================
  
  # Calcula próxima fecha programada según retry_interval
  # Soporta interval_days (legacy) y retry_interval_value/unit (nuevo)
  # ⭐ IMPORTANTE: Usar Time.current como base, NO scheduled_for
  # @return [ActiveSupport::TimeWithZone, nil]
  def next_scheduled_time
    # Priorizar retry_interval_value/unit si está presente
    if retry_interval_value.present? && retry_interval_unit.present?
      interval_minutes = case retry_interval_unit
                        when 'minutes' then retry_interval_value
                        when 'hours' then retry_interval_value * 60
                        when 'days' then retry_interval_value * 1440
                        else 0
                        end

      # ⭐ CORREGIDO: Usar Time.current como base para evitar ejecuciones inmediatas
      return Time.current + interval_minutes.minutes
    end

    # Fallback a interval_days (legacy)
    return nil unless interval_days.present?
    Time.current + interval_days.days
  end

  # ==============================================================================
  # Instance Methods - Manejo de intentos
  # ==============================================================================

  # Marca intento como fallido
  def mark_attempt_failed!(error_message = nil)
    update!(
      status: 'failed',
      last_attempt_at: Time.current,
      last_error: error_message
    )
  end

  # Marca intento como exitoso y gestiona reprogramación
  def mark_attempt_successful!(message_sent)
    increment!(:attempt_count)
    update!(
      last_attempt_at: Time.current,
      last_message_sent: message_sent,
      last_error: nil
    )

    if attempt_count >= max_attempts
      update!(status: 'completed')
    elsif retry_interval_value.present? || interval_days.present?
      reschedule_next_attempt
    end
  end

  # Reprograma siguiente intento
  def reschedule_next_attempt
    next_time = next_scheduled_time
    return unless next_time

    update!(
      scheduled_for: next_time,
      status: 'scheduled'
    )
    # NO llamar schedule_job aquí - el callback after_update lo hace automáticamente
  end

  # Reprograma a fecha específica (manual - cuando el contacto reagenda)
  def reschedule_to(new_datetime)
    # ✅ PERMITIR reagendar durante 'active' (es solicitud explícita del cliente)
    # ❌ NO permitir si ya está completado o cancelado
    return false if completed? || cancelled?

    # ⭐ Activar modo reintento automático
    enable_auto_retry_mode!

    # ⭐ REGLA: Resetear contador de repeticiones al reagendar
    # Así el intento actual puede repetirse hasta max_attempts veces
    Rails.logger.info "[ContactTracking] 🔄 Reagendamiento activado para tracking #{id}"
    Rails.logger.info "[ContactTracking]    Intento actual: #{attempt_count + 1}"
    Rails.logger.info "[ContactTracking]    Repeticiones anteriores: #{response_adjustments_count} → 0 (reseteado)"

    update(
      scheduled_for: new_datetime,
      status: 'scheduled',
      response_adjustments_count: 0  # ⭐ Resetear para permitir max_attempts repeticiones
      # attempt_count se mantiene sin cambios - misma plantilla
    )
    # NO llamar schedule_job aquí - el callback after_update lo hace automáticamente
  end

  # ==============================================================================
  # Instance Methods - Acciones de control
  # ==============================================================================

  # Pausa el seguimiento
  def pause!
    return false unless can_pause?

    # ⭐ IMPORTANTE: Cancelar jobs programados al pausar
    cancel_existing_jobs
    Rails.logger.info "[ContactTracking] ⏸️  Tracking #{id} pausado - jobs cancelados"

    # ⭐ Registrar evento de pausa en el contexto
    pause_time = Time.current
    context_entry = "\n\n⏸️ PAUSADO: #{pause_time.strftime('%d/%m/%Y %H:%M')} - Intento #{attempt_count + 1}/#{max_attempts}"

    update(
      status: 'paused',
      paused_at: pause_time,
      ai_context: "#{ai_context}#{context_entry}"
    )
  end

  # Reanuda el seguimiento
  # @param new_scheduled_time [DateTime, nil] Fecha/hora del siguiente intento (opcional)
  #   Si no se proporciona, se calcula automáticamente desde el momento actual + intervalo
  def resume!(new_scheduled_time = nil)
    return false unless can_resume?

    # Si no se proporciona fecha, calcular automáticamente
    new_scheduled_time ||= calculate_next_execution_from_now

    # Validar que la fecha sea futura
    if new_scheduled_time <= Time.current
      errors.add(:scheduled_for, 'debe ser una fecha futura')
      return false
    end

    Rails.logger.info "[ContactTracking] ▶️  Reanudando tracking #{id}"
    Rails.logger.info "[ContactTracking]    Pausado desde: #{paused_at}" if paused_at.present?
    Rails.logger.info "[ContactTracking]    Nueva fecha:   #{new_scheduled_time}"

    # ⭐ IMPORTANTE: Cancelar jobs existentes ANTES del update para evitar duplicados
    cancel_existing_jobs

    # ⭐ Registrar evento de reanudación en el contexto
    resume_time = Time.current
    pause_duration = paused_at.present? ? "Estuvo pausado #{time_ago_in_words_simple(paused_at)}" : ''
    context_entry = "\n\n▶️ REANUDADO: #{resume_time.strftime('%d/%m/%Y %H:%M')} → Próximo intento: #{new_scheduled_time.strftime('%d/%m/%Y %H:%M')}#{pause_duration.present? ? " (#{pause_duration})" : ''}"

    update(
      status: 'scheduled',
      scheduled_for: new_scheduled_time,
      paused_at: nil,
      ai_context: "#{ai_context}#{context_entry}"
    )

    # ⭐ NO llamar schedule_job aquí - el callback reschedule_job_if_needed lo hace automáticamente
    # Esto evita la DOBLE PROGRAMACIÓN de jobs
    true
  end

  # Helper para calcular tiempo transcurrido de forma simple
  def time_ago_in_words_simple(from_time)
    return '' unless from_time

    seconds = (Time.current - from_time).to_i
    case seconds
    when 0..59 then "#{seconds} segundos"
    when 60..3599 then "#{seconds / 60} minutos"
    when 3600..86_399 then "#{seconds / 3600} horas"
    else "#{seconds / 86_400} días"
    end
  end

  # Calcula la próxima ejecución desde el momento actual + intervalo
  def calculate_next_execution_from_now
    if retry_interval_value.present? && retry_interval_unit.present?
      interval_minutes = case retry_interval_unit
                        when 'minutes' then retry_interval_value
                        when 'hours' then retry_interval_value * 60
                        when 'days' then retry_interval_value * 1440
                        else 15 # Default 15 minutos
                        end

      return Time.current + interval_minutes.minutes
    end

    # Fallback a interval_days (legacy) o 1 día por defecto
    Time.current + (interval_days || 1).days
  end

  # Cancela el seguimiento
  def cancel!
    return false unless can_cancel?
    cancel_existing_jobs
    update(status: 'cancelled')
  end

  private

  # ==============================================================================
  # Private Methods - Validaciones custom
  # ==============================================================================

  def scheduled_for_cannot_be_in_past
    if scheduled_for.present? && scheduled_for < Time.current
      errors.add(:scheduled_for, 'cannot be in the past')
    end
  end

  def conversation_belongs_to_inbox
    if conversation.present? && conversation.inbox_id != inbox_id
      errors.add(:conversation, 'must belong to the selected inbox')
    end
  end

  # Verifica que solo exista un tracking activo por contacto
  # proyecto@contact_tracking: 1 seguimiento activo por (contacto, inbox).
  # Permite seguimientos en paralelo en canales (inboxes) distintos.
  def only_one_active_tracking_per_contact_and_inbox
    active_statuses = %w[pending scheduled active paused]

    existing = ContactTracking
      .where(contact_id: contact_id, inbox_id: inbox_id)
      .where(status: active_statuses)
      .where.not(id: id)
      .exists?

    if existing
      errors.add(:base,
        'Ya existe un seguimiento activo para este contacto en este canal. ' \
        'Completa o cancela el actual antes de crear uno nuevo.')
    end
  end

  # Verifica si está intentando usar plantillas WhatsApp
  def using_templates?
    whatsapp_templates.is_a?(Array) && whatsapp_templates.any? { |t| t.present? }
  end

  # Valida que todas las plantillas estén completas según max_attempts
  def all_templates_must_be_present
    return unless whatsapp_templates.is_a?(Array)

    # Si hay alguna plantilla configurada, todas deben estar presentes
    templates_count = whatsapp_templates.count { |t| t.present? }

    if templates_count > 0 && templates_count < max_attempts
      errors.add(
        :whatsapp_templates,
        "debe tener #{max_attempts} plantillas configuradas (tienes #{templates_count}). " \
        "Completa todas las plantillas o déjalas todas vacías para usar mensajes con IA."
      )
    end

    # Validar que no haya "huecos" (nil entre plantillas)
    if templates_count > 0
      max_attempts.times do |i|
        if whatsapp_templates[i].blank?
          errors.add(
            :whatsapp_templates,
            "la plantilla para el intento #{i + 1} no puede estar vacía. " \
            "Debes configurar todas las plantillas del 1 al #{max_attempts}."
          )
          break
        end
      end
    end
  end

  # ==============================================================================
  # Private Methods - Callbacks
  # ==============================================================================

  def ensure_account_id
    self.account_id ||= contact.account_id if contact.present?
  end
  
  # ⭐ NUEVO: Asegura que whatsapp_templates siempre sea un array válido
  def ensure_whatsapp_templates_array
    self.whatsapp_templates = [] if whatsapp_templates.nil?
    self.whatsapp_templates = [] unless whatsapp_templates.is_a?(Array)
    # proyecto@contact_tracking: keyword_actions
    self.keyword_actions = [] unless keyword_actions.is_a?(Array)
  end

  def schedule_job
    # Programar nuevo job
    begin
      ContactTrackingJob.set(wait_until: scheduled_for).perform_later(id)
      Rails.logger.info "[ContactTracking] ✅ Job programado para tracking #{id} a las #{scheduled_for.strftime('%H:%M:%S')}"
    rescue StandardError => e
      Rails.logger.error "[ContactTracking] ❌ Error al programar job: #{e.message}"
      # No relanzar el error para no bloquear la creación del tracking
    end
  end

  # ⭐ MEJORADO: Cancela todos los jobs existentes de este tracking en TODAS las colas de Sidekiq
  def cancel_existing_jobs
    require 'sidekiq/api'

    cancelled_count = 0

    begin
      # Buscar en ScheduledSet (jobs programados para el futuro)
      cancelled_count += cancel_jobs_in_set(Sidekiq::ScheduledSet.new, 'ScheduledSet')

      # ⭐ FIX: Buscar en TODAS las colas relevantes, incluyendo scheduled_jobs
      # ContactTrackingJob usa queue_as :scheduled_jobs
      %w[default scheduled_jobs mailers low high].each do |queue_name|
        begin
          queue = Sidekiq::Queue.new(queue_name)
          cancelled_count += cancel_jobs_in_set(queue, "Queue:#{queue_name}")
        rescue StandardError
          # Ignorar colas que no existen
        end
      end

      # Buscar en RetrySet (jobs que fallaron y se reintentarán)
      cancelled_count += cancel_jobs_in_set(Sidekiq::RetrySet.new, 'RetrySet')

      Rails.logger.info "[ContactTracking] 🧹 #{cancelled_count} job(s) cancelado(s) en total" if cancelled_count > 0
    rescue StandardError => e
      # No fallar si Sidekiq no está disponible o hay error
      Rails.logger.warn "[ContactTracking] ⚠️  No se pudieron cancelar jobs antiguos: #{e.message}"
      Rails.logger.warn "[ContactTracking] ⚠️  Backtrace: #{e.backtrace.first(3).join("\n")}"
    end
  end

  # Cancela jobs en un conjunto específico de Sidekiq
  def cancel_jobs_in_set(job_set, set_name)
    count = 0

    job_set.each do |job|
      if matches_this_tracking_job?(job)
        time_str = job.respond_to?(:at) ? Time.at(job.at).strftime('%H:%M:%S') : 'executing'
        Rails.logger.debug "[ContactTracking] 🗑️  Cancelando job en #{set_name} para tracking #{id} (#{time_str})"
        job.delete
        count += 1
      end
    end

    count
  end

  # Verifica si un job de Sidekiq pertenece a este tracking
  def matches_this_tracking_job?(job)
    return false unless job.args.is_a?(Array) && job.args.first.is_a?(Hash)

    job_data = job.args.first
    job_class = job_data['job_class']
    job_arguments = job_data['arguments']

    job_class == 'ContactTrackingJob' && job_arguments&.first == id
  end

  # ⭐ Reprograma job si scheduled_for cambió
  # ⭐ FIX: Agregada condición !paused? para evitar doble programación al reanudar
  def reschedule_job_if_needed
    # Solo reprogramar si:
    # 1. El scheduled_for cambió
    # 2. El tracking NO está completado ni cancelado
    # 3. El tracking NO está en proceso de ejecución (active)
    # 4. El tracking NO está pausado (evita programar al pausar)
    return unless saved_change_to_scheduled_for?
    return if completed? || cancelled? || active? || paused?

    Rails.logger.info "[ContactTracking] 🔄 Callback: Reprogramando job para tracking #{id}"
    Rails.logger.info "[ContactTracking]    Hora anterior: #{saved_change_to_scheduled_for[0]}"
    Rails.logger.info "[ContactTracking]    Hora nueva:    #{scheduled_for}"

    # Cancelar jobs antiguos y programar nuevo
    cancel_existing_jobs
    schedule_job
  end
end

# frozen_string_literal: true
# proyecto@bot_comando

# == Schema Information
#
# Table name: command_sessions
#
#  id              :bigint           not null, primary key
#  collected_data  :jsonb
#  command         :string           not null
#  current_step    :string           not null
#  expires_at      :datetime         not null
#  last_error      :text
#  status          :string           default("active"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  contact_id      :bigint           not null
#  conversation_id :bigint           not null
#  inbox_id        :bigint           not null
#  user_id         :bigint           not null
#
# Indexes
#
#  index_command_sessions_on_account_id               (account_id)
#  index_command_sessions_on_contact_id               (contact_id)
#  index_command_sessions_on_conversation_and_status  (conversation_id,status)
#  index_command_sessions_on_conversation_id          (conversation_id)
#  index_command_sessions_on_inbox_id                 (inbox_id)
#  index_command_sessions_on_status_and_expires_at    (status,expires_at)
#  index_command_sessions_on_user_id                  (user_id)
#  index_unique_active_session_per_conversation       (conversation_id) UNIQUE WHERE ((status)::text = 'active'::text)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (inbox_id => inboxes.id)
#  fk_rails_...  (user_id => users.id)
#

class CommandSession < ApplicationRecord
  # ==============================================================================
  # Constants
  # ==============================================================================
  EXPIRATION_MINUTES = 30

  # ==============================================================================
  # Associations
  # ==============================================================================
  belongs_to :account
  belongs_to :user
  belongs_to :contact
  belongs_to :conversation
  belongs_to :inbox

  # ==============================================================================
  # Enums - Estados posibles de la sesion
  # ==============================================================================
  enum status: {
    active: 'active',         # Sesion en curso, esperando respuesta del agente
    completed: 'completed',   # Comando ejecutado exitosamente
    cancelled: 'cancelled',   # Cancelado por el agente (/cancelar)
    expired: 'expired'        # Expirado por inactividad (30 min)
  }

  # ==============================================================================
  # Validations
  # ==============================================================================
  validates :command, presence: true
  validates :current_step, presence: true
  validates :status, presence: true
  validates :expires_at, presence: true

  # ==============================================================================
  # Scopes
  # ==============================================================================
  scope :active_sessions, -> { where(status: 'active') }
  scope :expired_pending, -> { active_sessions.where('expires_at < ?', Time.current) }
  scope :for_conversation, ->(conversation_id) { where(conversation_id: conversation_id) }
  scope :recent, -> { order(created_at: :desc) }

  # ==============================================================================
  # Callbacks
  # ==============================================================================
  before_validation :set_default_expires_at, on: :create

  # ==============================================================================
  # Class Methods
  # ==============================================================================

  # Busca sesion activa para una conversacion
  # @param conversation_id [Integer]
  # @return [CommandSession, nil]
  def self.active_for_conversation(conversation_id)
    active_sessions.for_conversation(conversation_id).first
  end

  # Expira todas las sesiones abandonadas
  # @return [Integer] Numero de sesiones expiradas
  def self.expire_abandoned_sessions!
    count = 0
    expired_pending.find_each do |session|
      session.expire!
      count += 1
    end
    count
  end

  # ==============================================================================
  # Instance Methods - Control de estado
  # ==============================================================================

  # Completa la sesion exitosamente
  def complete!
    update!(status: 'completed')
  end

  # Cancela la sesion (por /cancelar)
  def cancel!
    update!(status: 'cancelled')
  end

  # Expira la sesion por inactividad
  def expire!
    update!(status: 'expired')
  end

  # Extiende el tiempo de expiracion (se llama al recibir respuesta)
  def extend_expiration!
    update!(expires_at: EXPIRATION_MINUTES.minutes.from_now)
  end

  # ==============================================================================
  # Instance Methods - Manejo de datos recolectados
  # ==============================================================================

  # Actualiza un campo en collected_data
  # @param key [String, Symbol]
  # @param value [Object]
  def set_data(key, value)
    self.collected_data ||= {}
    self.collected_data[key.to_s] = value
    save!
  end

  # Obtiene un valor de collected_data
  # @param key [String, Symbol]
  # @return [Object, nil]
  def get_data(key)
    collected_data&.dig(key.to_s)
  end

  # Actualiza multiples campos a la vez
  # @param data [Hash]
  def merge_data(data)
    self.collected_data ||= {}
    self.collected_data.merge!(data.stringify_keys)
    save!
  end

  # ==============================================================================
  # Instance Methods - Navegacion del flujo
  # ==============================================================================

  # Avanza al siguiente paso
  # @param step_name [String]
  def advance_to!(step_name)
    update!(current_step: step_name)
    extend_expiration!
  end

  # Registra un error en la sesion
  # @param error_message [String]
  def record_error!(error_message)
    update!(last_error: error_message)
  end

  # ==============================================================================
  # Instance Methods - Verificaciones
  # ==============================================================================

  # Verifica si la sesion ha expirado
  def expired?
    status == 'expired' || (status == 'active' && expires_at < Time.current)
  end

  # Verifica si la sesion esta activa y no ha expirado
  def still_active?
    status == 'active' && expires_at >= Time.current
  end

  private

  # ==============================================================================
  # Private Methods - Callbacks
  # ==============================================================================

  def set_default_expires_at
    self.expires_at ||= EXPIRATION_MINUTES.minutes.from_now
  end
end

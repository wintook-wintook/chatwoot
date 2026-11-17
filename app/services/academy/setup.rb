# frozen_string_literal: true

# Academia Kontrolya — ¿ya está configurado? Los pasos «setup» de «Configura tu cuenta» y
# «Tu perfil» no son ejercicios: se revisan en vivo con cómo está la cuenta (o el usuario) y
# cuentan aunque lo haya hecho otra persona o antes de entrar a la Academia.
#
# Lo que ya trae valores de fábrica (etapas, motivos) se da por hecho cuando alguien lo cambió;
# si así le sirve, el administrador lo acepta a mano («Así me sirve», en el Board).
#
#   Academy::Setup.new(account:, user:).call('whatsapp') → true | false
class Academy::Setup
  CHECKS = %w[company whatsapp team roles inbox_members case_stages close_reasons task_outcomes
              canned_responses whatsapp_templates working_hours catalog budget contacts_import
              avatar signature google phone dali].freeze

  def initialize(account:, user:)
    @account = account
    @user = user
  end

  def call(check)
    raise ArgumentError, "setup desconocido: #{check}" unless CHECKS.include?(check.to_s)

    public_send("#{check}?") ? true : false
  end

  # ── La cuenta ──────────────────────────────────────────────────────────────
  def company? = @account.brand_logo.attached?

  def whatsapp? = whatsapp_inboxes.exists?

  def team? = @account.account_users.count > 1

  # Cada compañero que no es administrador tiene su rol elegido (no el de por omisión).
  def roles?
    return false unless team?

    @account.account_users.where.not(role: :administrator).where(access_role_id: nil).none?
  end

  # Cada bandeja tiene quién la atienda.
  def inbox_members?
    inboxes = @account.inboxes
    inboxes.exists? && inboxes.where.not(id: InboxMember.select(:inbox_id)).none?
  end

  def case_stages?
    types = @account.case_types.active
    edited?(types) || edited?(CaseTypeColumn.where(case_type_id: types.select(:id)))
  end

  def close_reasons? = edited?(@account.case_outcome_reasons)

  def task_outcomes? = edited?(@account.task_outcomes)

  def canned_responses? = @account.canned_responses.exists?

  def whatsapp_templates?
    Channel::Whatsapp.where(id: whatsapp_inboxes.select(:channel_id))
                     .exists?(["COALESCE(message_templates::text, '{}') NOT IN ('{}', '[]', 'null')"])
  end

  def working_hours? = @account.inboxes.exists?(working_hours_enabled: true)

  def catalog? = @account.catalog_items.exists?

  def budget? = @account.sales_budget_lines.exists?

  def contacts_import?
    @account.data_imports.exists? || @account.contacts.where.not(id: Academy::Practice.scope(@account).select(:id)).offset(19).exists?
  end

  # ── El usuario ─────────────────────────────────────────────────────────────
  def avatar? = @user.avatar.attached?

  def signature? = @user.message_signature.present?

  def google? = UserCalendarIntegration.exists?(account_id: @account.id, user_id: @user.id)

  # Dali en el teléfono: activó sus avisos ahí o ya le escribió desde la app.
  def phone?
    NotificationSubscription.where(user_id: @user.id).where("subscription_attributes ->> 'dali' = 'true'").exists? ||
      my_threads.exists?(['messages @> ?', [{ context: { page: 'dali_app' } }].to_json])
  end

  def dali? = my_threads.where('jsonb_array_length(messages) > 0').exists?

  private

  def whatsapp_inboxes = @account.inboxes.where(channel_type: 'Channel::Whatsapp')

  def my_threads = AssistantThread.where(account_id: @account.id, user_id: @user.id)

  # Alguien lo cambió: editó un registro o agregó uno después de los de fábrica.
  def edited?(scope)
    first = scope.minimum(:created_at)
    return false unless first

    scope.exists?(["updated_at > created_at + interval '1 minute' OR created_at > ?", first + 10.minutes])
  end
end

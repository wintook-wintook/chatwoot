# ================================================================================
# feat/licencias (F3) — CUANDO UNA LICENCIA VENCE
# ================================================================================
# Lo corre Licenses::ExpirationJob cada hora:
#
#   licencia activa vencida → expired
#     ¿hay una programada?  sí → se promueve (sin corte; reactiva la cuenta si estaba suspendida)
#                           no → la cuenta se suspende (solo con el interruptor encendido y si
#                                no es «Cuenta de Wintook»)
#   programada cuyo inicio ya pasó sin activa → se promueve (p. ej. la activa se canceló)
#   con el interruptor encendido: cuentas que tuvieron licencia, no tienen activa ni en cola y
#   siguen activas → se suspenden (cubre encender el interruptor con vencidas de antes)
#
# La programada conserva su inicio: arranca cuando terminó la anterior aunque el job corra con
# retraso, así no se regalan ni se comen días. Si también venció, se encadena a la siguiente.
# Apagado el interruptor, las licencias se marcan vencidas igual (el tablero lo refleja) pero no
# se suspende nada.
# Plan: docs/licencias_plan_v1.md §5 y §11
# ================================================================================
class Licenses::ExpirationService
  def initialize(now: Time.current)
    @now = now
  end

  def perform
    AccountLicense.active.where(expires_at: ..@now).pluck(:account_id).uniq.each { |id| roll(id) }
    promote_orphans
    suspend_lapsed if Licenses::Enforcement.enabled?
  end

  private

  def roll(account_id)
    Account.transaction do
      account = Account.lock.find(account_id)
      expire_and_promote(account)
      suspend(account) if account.account_licenses.active.none?
    end
  end

  # Vence la activa y promueve la siguiente; si esa también venció, sigue con la próxima.
  def expire_and_promote(account)
    loop do
      vencida = account.account_licenses.active.where(expires_at: ..@now).first
      return if vencida.nil?

      vencida.update!(status: :expired)
      return unless promote_next(account)
    end
  end

  # true si promovió una programada (la siguiente por fecha de inicio).
  def promote_next(account)
    siguiente = account.account_licenses.scheduled.order(:starts_at, :id).first
    return false unless siguiente

    siguiente.update!(status: :active)
    account.update!(status: :active) if account.suspended?
    true
  end

  def promote_orphans
    ids = AccountLicense.scheduled.where(starts_at: ..@now).where.not(account_id: AccountLicense.active.select(:account_id)).pluck(:account_id)
    ids.uniq.each do |id|
      Account.transaction { promote_next(Account.lock.find(id)) }
    end
  end

  def suspend_lapsed
    con_vigencia = AccountLicense.where(status: %i[active scheduled]).select(:account_id)
    Account.active.where(id: AccountLicense.select(:account_id)).where.not(id: con_vigencia).find_each { |account| suspend(account) }
  end

  def suspend(account)
    return unless Licenses::Enforcement.enabled?
    return if account.wintook_internal? || account.suspended?

    account.update!(status: :suspended)
    Rails.logger.info "[LICENSES] cuenta #{account.id} suspendida: licencia vencida sin periodo en cola"
  end
end

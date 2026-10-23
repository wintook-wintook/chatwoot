# ================================================================================
# feat/licencias (F2) — LA VISTA CRUZADA DE CUENTAS
# ================================================================================
# GET …/licenses/accounts?estado=&dias=&q=&page=&per_page=
#   estado  sin_licencia · demo · vigente · por_vencer · vencida (vacío = todas)
#   dias    para por_vencer (7 por omisión)
#   q       nombre o id
# GET …/licenses/accounts/:id → la cuenta con su historial de licencias
# «Sin licencia» = no gestionada (como hoy); «vencida» = tuvo licencia y ninguna está activa.
# ================================================================================
class Api::V1::Accounts::Licenses::AccountsController < Api::V1::Accounts::Licenses::BaseController
  MAX_PER_PAGE = 100

  def index
    cuentas = filtered.order(id: :desc)
    total = cuentas.count
    pagina = cuentas.includes(:current_license).offset((page - 1) * per_page).limit(per_page).to_a
    render json: { accounts: rows(pagina), meta: { page: page, per_page: per_page, total: total, total_pages: (total.to_f / per_page).ceil } }
  end

  def show
    cuenta = Account.find(params[:id])
    render json: rows([cuenta]).first.merge(licenses: cuenta.account_licenses.order(created_at: :desc).map { |l| license_json(l) })
  end

  private

  def filtered
    cuentas = search(Account.all)
    con_licencia = AccountLicense.select(:account_id)
    activas = AccountLicense.active
    case params[:estado]
    when 'sin_licencia' then cuentas.where.not(id: con_licencia)
    when 'demo' then cuentas.where(id: activas.demo.select(:account_id))
    when 'vigente' then cuentas.where(id: activas.paid.select(:account_id))
    when 'por_vencer' then cuentas.where(id: activas.where(expires_at: ..dias.days.from_now).select(:account_id))
    when 'vencida' then cuentas.where(id: con_licencia).where.not(id: activas.select(:account_id))
    else cuentas
    end
  end

  def search(cuentas)
    q = params[:q].to_s.strip
    return cuentas if q.blank?
    return cuentas.where(id: q.to_i) if q.match?(/\A\d+\z/)

    cuentas.where('accounts.name ILIKE ?', "%#{ActiveRecord::Base.sanitize_sql_like(q)}%")
  end

  # Los conteos van en tres consultas para toda la página, no una por cuenta.
  def rows(cuentas)
    ids = cuentas.map(&:id)
    conteos = {
      agentes: AccountUser.where(account_id: ids).group(:account_id).count,
      en_cola: AccountLicense.scheduled.where(account_id: ids).group(:account_id).count,
      con_historia: AccountLicense.where(account_id: ids).distinct.pluck(:account_id)
    }
    cuentas.map { |cuenta| row(cuenta, conteos) }
  end

  def row(cuenta, conteos)
    licencia = cuenta.current_license
    { id: cuenta.id, name: cuenta.name, status: cuenta.status, wintook_internal: cuenta.wintook_internal?,
      agents_count: conteos[:agentes][cuenta.id].to_i, scheduled_count: conteos[:en_cola][cuenta.id].to_i,
      license_state: state(licencia, conteos[:con_historia].include?(cuenta.id)),
      license: licencia && license_json(licencia) }
  end

  def state(licencia, con_historia)
    return licencia.license_type if licencia
    return 'vencida' if con_historia

    'sin_licencia'
  end

  def license_json(licencia)
    licencia.slice(:id, :name, :license_type, :status, :max_agents, :duration_days, :starts_at, :expires_at, :notes, :license_plan_id)
            .merge(days_left: licencia.expires_at && ((licencia.expires_at - Time.current) / 1.day).ceil,
                   created_by: licencia.created_by&.name)
  end

  def dias
    params[:dias].to_i.positive? ? params[:dias].to_i : 7
  end

  def page
    [params[:page].to_i, 1].max
  end

  def per_page
    params[:per_page].to_i.positive? ? [params[:per_page].to_i, MAX_PER_PAGE].min : 25
  end
end

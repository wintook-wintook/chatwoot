# frozen_string_literal: true

# Academia Kontrolya — «Mi capacitación» de un usuario: sus módulos (los de su rol), cada paso
# con cómo va, y las acciones:
#   start(mod, step)  «Hazlo» / «Leer»: una lección queda leída; un ejercicio empieza a contar
#   check(mod, step)  «Revisar»: corre Academy::Checks y, si lo encuentra, lo da por hecho
#   confirm(mod, step) «Así me sirve»: da por hecho a mano un paso de configuración (setup)
#
# Los pasos setup (Configura tu cuenta, Tu perfil) se revisan en vivo con Academy::Setup. En un
# módulo shared lo que confirma un administrador vale para toda la cuenta.
#
#   Academy::Board.new(account:, user:, grant:).call → { modules: […], practice: {…}, done:, total: }
class Academy::Board
  class NotFound < StandardError; end
  CONFIRMED = 'confirmed' # evidence_type de un paso que se dio por hecho a mano

  def initialize(account:, user:, grant:)
    @account = account
    @user = user
    @grant = grant
    @practice = Academy::Practice.new(account, user)
    @setup = Academy::Setup.new(account: account, user: user)
    @live = {}
  end

  def call
    fresh!
    mods = Academy::Catalog.for(@grant).map { |mod| module_json(mod) }
    { modules: mods, practice: practice_json,
      done: mods.sum { |m| m[:done] }, total: mods.sum { |m| m[:total] } }
  end

  def start(module_key, step_key)
    mod, step = find!(module_key, step_key)
    row = row_for(module_key, step_key)
    row.started_at ||= Time.current
    row.completed_at ||= Time.current if step.lesson?
    row.save!
    step_json(mod, step, row)
  end

  # «Así me sirve» (undo: deshacerlo). Solo en pasos setup que lo permiten.
  def confirm(module_key, step_key, undo: false)
    mod, step = find!(module_key, step_key)
    raise NotFound, 'Ese paso no se confirma a mano' unless step.setup? && step.confirm.present?

    undo ? unconfirm!(mod, step) : confirm!(mod, step)
    fresh!
    step_json(mod, step, rows[[mod.key, step.key]])
  end

  # → { step:, found: true|false, message: }
  def check(module_key, step_key)
    mod, step = find!(module_key, step_key)
    raise NotFound, 'Una lección no se revisa' if step.lesson?
    return check_setup(mod, step) if step.setup?

    check_exercise(mod, step)
  end

  private

  def check_exercise(mod, step)
    row = row_for(mod.key, step.key)
    return { step: step_json(mod, step, row), found: true } if row.done?

    first_time = row.started_at.nil?
    row.started_at ||= Time.current
    row.attempts += 1
    evidence = Academy::Checks.new(account: @account, user: @user, since: row.started_at).call(step.check)
    row.assign_attributes(completed_at: Time.current, evidence_type: evidence.class.name, evidence_id: evidence.id) if evidence
    row.save!
    { step: step_json(mod, step, row), found: evidence.present?, message: evidence ? nil : hint(step, first_time) }
  end

  def confirm!(mod, step)
    row = row_for(mod.key, step.key)
    row.started_at ||= Time.current
    row.update!(completed_at: Time.current, evidence_type: CONFIRMED, evidence_id: nil)
  end

  # En un módulo shared se deshace para toda la cuenta (lo haya aceptado quien sea).
  def unconfirm!(mod, step)
    scope = mod.shared ? shared_scope(mod).where(step_key: step.key) : AcademyProgress.where(id: own_row(mod, step)&.id)
    scope.where(evidence_type: CONFIRMED).find_each { |r| r.update!(completed_at: nil, evidence_type: nil) }
    @rows = nil
  end

  # Configuración: se revisa en vivo; si ya está, queda registrado quién lo vio hecho.
  def check_setup(mod, step)
    fresh!
    row = row_for(mod.key, step.key)
    row.started_at ||= Time.current
    row.attempts += 1
    found = live?(step)
    row.completed_at ||= Time.current if found
    row.save!
    json = step_json(mod, step, row)
    { step: json, found: json[:status] == 'done', message: json[:status] == 'done' ? nil : step.hint }
  end

  # La configuración se revisa cada vez (puede cambiar entre una llamada y otra).
  def fresh!
    @live = {}
    @shared = nil
  end

  def live?(step)
    @live.fetch(step.check) { @live[step.check] = @setup.call(step.check) }
  end

  def own_row(mod, step) = rows[[mod.key, step.key]]

  def shared_scope(mod) = AcademyProgress.where(account_id: @account.id, module_key: mod.key)

  # Quién confirmó a mano cada paso de un módulo shared: { step_key => nombre }.
  def shared_confirmations(mod)
    @shared ||= {}
    @shared[mod.key] ||= shared_scope(mod).where(evidence_type: CONFIRMED).where.not(completed_at: nil)
                                          .includes(:user).order(:completed_at)
                                          .each_with_object({}) { |r, h| h[r.step_key] ||= r.user&.name.to_s }
  end

  def confirmed_by(mod, step, row)
    return shared_confirmations(mod)[step.key] if mod.shared

    row&.evidence_type == CONFIRMED && row.completed_at ? @user.name.to_s : nil
  end

  def find!(module_key, step_key)
    mod = Academy::Catalog.for(@grant).find { |m| m.key == module_key.to_s }
    step = mod&.step(step_key)
    raise NotFound, 'Ese paso no existe' unless step

    [mod, step]
  end

  def hint(step, first_time)
    return 'Listo, ya empezó a contar. Hazlo y vuelve a pulsar «Revisar».' if first_time && step.page.present?

    step.hint
  end

  def rows
    @rows ||= AcademyProgress.where(account_id: @account.id, user_id: @user.id).index_by { |r| [r.module_key, r.step_key] }
  end

  def row_for(module_key, step_key)
    rows[[module_key.to_s, step_key.to_s]] ||=
      AcademyProgress.new(account_id: @account.id, user_id: @user.id, module_key: module_key.to_s, step_key: step_key.to_s)
  end

  def module_json(mod)
    steps = mod.steps.map { |step| step_json(mod, step, rows[[mod.key, step.key]]) }
    done = steps.count { |s| s[:status] == 'done' }
    { key: mod.key, title: mod.title, summary: mod.summary, steps: steps, done: done, total: steps.size,
      status: module_status(done, steps) }
  end

  def module_status(done, steps)
    return 'done' if done == steps.size
    return 'in_progress' if steps.any? { |s| s[:status] != 'pending' }

    'pending'
  end

  def step_json(mod, step, row)
    json = { key: step.key, kind: step.kind, title: step.title, text: step.text, guide: step.guide,
             path: path_for(step), needs: step.needs, blocked: blocked?(step), status: status_of(row),
             started_at: row&.started_at, completed_at: row&.completed_at, attempts: row&.attempts.to_i }
    json.merge!(setup_json(mod, step, row)) if step.setup?
    json.compact
  end

  def setup_json(mod, step, row)
    by = confirmed_by(mod, step, row)
    live = live?(step)
    status = if live || by then 'done'
             elsif row&.started_at then 'started'
             else
               'pending'
             end
    { status: status, level: step.level, confirm: step.confirm, ask: step.ask,
      confirmed_by: live ? nil : by, completed_at: status == 'done' ? row&.completed_at : nil }
  end

  def status_of(row)
    return 'pending' unless row&.started_at || row&.completed_at

    row.done? ? 'done' : 'started'
  end

  # Le falta el Cliente de práctica o su caso para poder hacerlo.
  def blocked?(step)
    case step.needs
    when 'practice_contact' then @practice.contact.nil?
    when 'practice_case' then @practice.case.nil?
    else false
    end
  end

  def path_for(step)
    case step.page
    when 'practice_contact' then @practice.contact && "contacts/#{@practice.contact.id}"
    when 'practice_case' then @practice.case && "tickets/#{@practice.case.id}"
    when nil then nil
    else Assistant::Pages::SCREENS.dig(step.page, 'path')
    end
  end

  def practice_json
    contact = @practice.contact
    { contact_id: contact&.id, contact_name: contact&.name, case_id: @practice.case&.id }
  end
end

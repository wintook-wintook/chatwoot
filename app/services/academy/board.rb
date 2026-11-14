# frozen_string_literal: true

# Academia Kontrolya — «Mi capacitación» de un usuario: sus módulos (los de su rol), cada paso
# con cómo va, y las acciones:
#   start(mod, step)  «Hazlo» / «Leer»: una lección queda leída; un ejercicio empieza a contar
#   check(mod, step)  «Revisar»: corre Academy::Checks y, si lo encuentra, lo da por hecho
#
#   Academy::Board.new(account:, user:, grant:).call → { modules: […], practice: {…}, done:, total: }
class Academy::Board
  class NotFound < StandardError; end

  def initialize(account:, user:, grant:)
    @account = account
    @user = user
    @grant = grant
    @practice = Academy::Practice.new(account, user)
  end

  def call
    mods = Academy::Catalog.for(@grant).map { |mod| module_json(mod) }
    { modules: mods, practice: practice_json,
      done: mods.sum { |m| m[:done] }, total: mods.sum { |m| m[:total] } }
  end

  def start(module_key, step_key)
    _mod, step = find!(module_key, step_key)
    row = row_for(module_key, step_key)
    row.started_at ||= Time.current
    row.completed_at ||= Time.current if step.lesson?
    row.save!
    step_json(step, row)
  end

  # → { step:, found: true|false, message: }
  def check(module_key, step_key)
    _mod, step = find!(module_key, step_key)
    raise NotFound, 'Una lección no se revisa' if step.lesson?

    row = row_for(module_key, step_key)
    return { step: step_json(step, row), found: true } if row.done?

    first_time = row.started_at.nil?
    row.started_at ||= Time.current
    row.attempts += 1
    evidence = Academy::Checks.new(account: @account, user: @user, since: row.started_at).call(step.check)
    row.assign_attributes(completed_at: Time.current, evidence_type: evidence.class.name, evidence_id: evidence.id) if evidence
    row.save!
    { step: step_json(step, row), found: evidence.present?, message: evidence ? nil : hint(step, first_time) }
  end

  private

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
    steps = mod.steps.map { |step| step_json(step, rows[[mod.key, step.key]]) }
    done = steps.count { |s| s[:status] == 'done' }
    { key: mod.key, title: mod.title, summary: mod.summary, steps: steps, done: done, total: steps.size,
      status: module_status(done, steps) }
  end

  def module_status(done, steps)
    return 'done' if done == steps.size
    return 'in_progress' if steps.any? { |s| s[:status] != 'pending' }

    'pending'
  end

  def step_json(step, row)
    { key: step.key, kind: step.kind, title: step.title, text: step.text, guide: step.guide,
      path: path_for(step), needs: step.needs, blocked: blocked?(step), status: status_of(row),
      started_at: row&.started_at, completed_at: row&.completed_at, attempts: row&.attempts.to_i }.compact
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

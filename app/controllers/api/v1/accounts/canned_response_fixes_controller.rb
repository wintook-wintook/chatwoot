# frozen_string_literal: true

# proyecto@arreglar_predefinidas — los arreglos con IA de Respuestas predefinidas.
#   GET  …/canned_responses/:id/fix            «pasa del tope»: la última propuesta vigente (o null)
#   POST …/canned_responses/:id/fix            «pasa del tope»: pedir una nueva
#   GET  …/canned_response_fixes?finding_id=&kind=   la última vigente de un hallazgo (o null)
#   GET  …/canned_response_fixes?history=1     aplicados y deshechos de los últimos 30 días
#   GET  …/canned_response_fixes?batch=        las del lote de «Corregir todas»
#   POST …/canned_response_fixes { kind, finding_id, choices, extra_ids }
#        kind: writing | merge | separate | resolve
#   POST …/canned_response_fixes/resolve_preview { finding_id, choices }
#        contradicción: qué queda prohibido y en qué otras predefinidas aparece
#   POST …/canned_response_fixes/bulk_writing  redacción de bajo riesgo de toda la cuenta
#   GET  …/canned_response_fixes/:id           estado y propuesta
#   POST …/canned_response_fixes/:id/check { parts }
#   POST …/canned_response_fixes/:id/apply { parts, force }
#   POST …/canned_response_fixes/:id/discard
#   POST …/canned_response_fixes/:id/undo { force }
class Api::V1::Accounts::CannedResponseFixesController < Api::V1::Accounts::BaseController
  FINDING_KINDS = { 'writing' => %w[writing], 'merge' => %w[duplicate overlap], 'separate' => %w[overlap],
                    'resolve' => %w[contradiction] }.freeze
  # «Corregir todas»: solo lo de bajo riesgo, y hasta BULK_MAX por lote.
  BULK_TYPES = %w[ortografia numeracion].freeze
  BULK_MAX = 30
  MAX_EXTRA = 10
  HISTORY_MAX = 50

  before_action :fetch_canned, only: [:latest, :create_oversize]
  before_action :fetch_fix, only: [:show, :check, :apply, :discard, :undo]
  before_action :fetch_finding, only: [:resolve_preview]

  def index
    return render json: history if params[:history].present?
    return render json: scope.where(batch: params[:batch]).order(:id).map(&:as_fix_json) if params[:batch].present?

    fix = scope.where(finding_id: params[:finding_id], kind: params[:kind]).order(:id).last
    render json: current(fix)&.as_fix_json
  end

  def latest
    render json: current(scope.where(kind: 'oversize', canned_response: @canned).order(:id).last)&.as_fix_json
  end

  def create_oversize
    return no_key unless openai_key?

    render json: start('oversize', [@canned]).as_fix_json
  end

  def show
    render json: @fix.as_fix_json
  end

  def create
    return no_key unless openai_key?

    kind = params.require(:kind)
    return head :unprocessable_entity unless FINDING_KINDS.key?(kind)

    hallazgo = Current.account.canned_response_findings.find(params.require(:finding_id))
    return head :unprocessable_entity unless FINDING_KINDS[kind].include?(hallazgo.kind)

    fuentes, entrada = sources_and_input(kind, hallazgo)
    return render json: { error: 'choices' }, status: :unprocessable_entity if fuentes.nil?

    render json: start(kind, fuentes, finding: hallazgo, input: entrada).as_fix_json
  end

  def resolve_preview
    resolucion = CannedResponses::Fix::Resolution.new(@finding.details['contradictions'], choices_param)
    render json: { forbidden: resolucion.forbidden, required: resolucion.required,
                   also_in: also_in(resolucion, [@finding.canned_response_id, @finding.other_canned_response_id]) }
  end

  def bulk_writing
    return no_key unless openai_key?

    lote = SecureRandom.hex(8)
    hallazgos = Current.account.canned_response_findings.unresolved.where(kind: 'writing').includes(:canned_response)
                       .select { |f| (Array(f.details['issues']).pluck('type') - BULK_TYPES).empty? }.first(BULK_MAX)
    hallazgos.each do |f|
      start('writing', [f.canned_response], finding: f, input: { 'issues' => f.details['issues'] }, batch: lote)
    end
    render json: { batch: lote, count: hallazgos.size }
  end

  def check
    return head :unprocessable_entity if @fix.stale_source?

    contexto = CannedResponses::Fix::Context.for(@fix)
    preguntas = Array(@fix.proposal['questions']).select { |q| q['part'].to_i < parts_param.size }
    render json: contexto.checks(api_key: api_key).call(parts_param, preguntas, embeddings: @fix.kind != 'writing')
  end

  def apply
    resultado = CannedResponses::Fix::Applier.new(@fix).call(parts: parts_param, force: bool(params[:force]))
    render json: @fix.reload.as_fix_json.merge(result: resultado)
  rescue CannedResponses::Fix::Applier::Blocked => e
    render json: { error: 'blocked', checks: e.checks }, status: :unprocessable_entity
  rescue CannedResponses::Fix::Applier::Stale
    render json: { error: 'stale' }, status: :conflict
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: 'invalid', message: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def discard
    @fix.update!(status: 'discarded') if %w[proposed failed running].include?(@fix.status)
    render json: @fix.as_fix_json
  end

  def undo
    CannedResponses::Fix::Undo.new(@fix).call(force: bool(params[:force]))
    render json: @fix.reload.as_fix_json
  rescue CannedResponses::Fix::Undo::NotUndoable
    render json: { error: 'not_undoable' }, status: :unprocessable_entity
  rescue CannedResponses::Fix::Undo::Conflict => e
    render json: { error: 'edited_since', names: e.names }, status: :conflict
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: 'invalid', message: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  private

  def scope = Current.account.canned_response_fixes

  # La que sigue en pie: no aplicada, no descartada y con el texto de origen igual.
  def current(fix)
    return nil if fix.nil? || %w[applied discarded undone].include?(fix.status)
    return nil if fix.status == 'proposed' && fix.stale_source?

    fix
  end

  def history
    scope.where(status: %w[applied undone]).where('updated_at > ?', CannedResponseFix::UNDO_DAYS.days.ago)
         .order(updated_at: :desc).limit(HISTORY_MAX).map(&:as_fix_json)
  end

  # Si ya hay una corriendo para lo mismo, esa.
  def start(kind, fuentes, finding: nil, input: {}, batch: nil)
    corriendo = scope.where(kind: kind, status: 'running', finding_id: finding&.id, canned_response_id: fuentes.first.id).order(:id).last
    return corriendo if corriendo && !corriendo.dead?

    scope.create!(kind: kind, finding: finding, canned_response: fuentes.first, user: current_user, batch: batch,
                  source_ids: fuentes.map(&:id), source_digests: fuentes.to_h { |r| [r.id.to_s, CannedResponseFix.digest_for(r)] },
                  source_digest: CannedResponseFix.digest_for(fuentes.first), input: input)
         .tap { |fix| CannedResponses::FixJob.perform_later(fix.id) }
  end

  # [fuentes, input] o [nil, nil] si faltan elecciones (resolve).
  def sources_and_input(kind, hallazgo)
    par = [hallazgo.canned_response, hallazgo.other_canned_response].compact
    case kind
    when 'writing' then [par.first(1), { 'issues' => hallazgo.details['issues'] }]
    when 'resolve' then resolve_sources(hallazgo, par)
    else [par, {}]
    end
  end

  def resolve_sources(hallazgo, par)
    contradicciones = Array(hallazgo.details['contradictions'])
    return [nil, nil] unless CannedResponses::Fix::Resolution.new(contradicciones, choices_param).complete?(contradicciones.size)

    extra = Current.account.canned_responses.where(id: Array(params[:extra_ids]).map(&:to_i) - par.map(&:id)).limit(MAX_EXTRA).to_a
    [par + extra, { 'contradictions' => contradicciones, 'choices' => choices_param, 'extra_ids' => extra.map(&:id) }]
  end

  # Las otras predefinidas de la cuenta donde también está el dato equivocado.
  def also_in(resolucion, excluir)
    datos = resolucion.wrong_data
    return [] if datos.empty?

    Current.account.canned_responses.where.not(id: excluir).filter_map do |r|
      coinciden = datos.select { |d| CannedResponses::Fix::HardData.new(r.agent_text).present?(d) }
      { id: r.id, short_code: r.short_code, matches: coinciden.pluck('text') } if coinciden.any?
    end.first(MAX_EXTRA * 2)
  end

  def choices_param
    Array(params[:choices]).map { |c| c.respond_to?(:permit) ? c.permit(:choice, :value).to_h : c.to_h.slice('choice', 'value') }
  end

  def fetch_canned
    @canned = Current.account.canned_responses.find(params[:id])
  end

  def fetch_fix
    @fix = scope.find(params[:id])
  end

  def fetch_finding
    @finding = Current.account.canned_response_findings.find_by!(id: params.require(:finding_id), kind: 'contradiction')
  end

  def parts_param
    @parts_param ||= Array(params[:parts]).map { |p| p.permit(:short_code, :content).to_h }
  end

  def bool(value) = ActiveModel::Type::Boolean.new.cast(value)
  def api_key = ContactTrackings::Assistant::OpenaiChat.new(account: Current.account).api_key
  def openai_key? = Current.account.hooks.exists?(app_id: 'openai', status: 'enabled')
  def no_key = render(json: { error: 'no_key' }, status: :unprocessable_entity)
end

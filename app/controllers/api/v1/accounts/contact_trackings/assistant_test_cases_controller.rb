# frozen_string_literal: true

# ================================================================================
# proyecto@diagrama_agente_ia — F3: LA PILA GUARDADA DE UN AGENTE
# ================================================================================
# GET    …/assistant/test_cases?template_id=        la pila, la corrida en seco en curso
#                                                   y lo que se ofrece en vivo (D5)
# POST   …/assistant/test_cases                     agregar una escrita a mano (message) o
#                                                   una sugerida (message + expected_route)
# POST   …/assistant/test_cases/generate            las de ruta y regla que falten
# PATCH  …/assistant/test_cases/:id                 fijarla (pinned)
# DELETE …/assistant/test_cases/:id
# POST   …/assistant/test_cases/run_dry             toda la pila en seco contra `draft`
# POST   …/assistant/test_cases/:id/dry             UNA en seco, al momento (la recién
#                                                   agregada o la elegida sin correr)
# POST   …/assistant/test_cases/run_live            las `case_ids` en vivo → { id } de la
#                                                   corrida (se sigue con test_battery/:id)
# POST   …/assistant/test_cases/compare             F5: toda la pila en seco contra la versión
#                                                   `version_id` y contra `draft`
#
# Mismo permiso que el resto del Asistente: administradores.
# ================================================================================

class Api::V1::Accounts::ContactTrackings::AssistantTestCasesController < Api::V1::Accounts::BaseController
  TestCases = ContactTrackings::Assistant::TestCases

  before_action :check_authorization
  before_action :fetch_template, except: [:update, :destroy, :dry_one]
  before_action :fetch_case, only: [:update, :destroy, :dry_one]

  def index
    render json: pile_json
  end

  def create
    turnos = params[:turns].is_a?(Array) ? params[:turns] : nil
    caso = TestCases.add_own(Current.account, @template, params[:message], expected_route: params[:expected_route],
                                                                           turns: turnos)
    return render json: { error: caso.errors.full_messages.join(' · ') }, status: :unprocessable_entity unless caso.persisted?

    render json: case_json(caso), status: :created
  end

  def generate
    encargo = params[:brief_id].present? ? TrackingAgentBrief.find_by(id: params[:brief_id], account: Current.account) : nil
    creados = TestCases.generate(Current.account, @template, brief: encargo)
    render json: pile_json.merge(created: creados.size)
  end

  def update
    @case.update!(pinned: ActiveModel::Type::Boolean.new.cast(params[:pinned]))
    render json: case_json(@case)
  end

  def destroy
    @case.destroy!
    head :no_content
  end

  def dry_one
    @template = @case.tracking_template
    TestCases.run_one_dry(Current.account, @case, draft: params[:draft].presence || @template.complementary_prompt,
                                                  inbox: inbox)
    render json: case_json(@case.reload)
  end

  def run_dry
    estado = TestCases.run_dry(Current.account, @template, draft: params[:draft].presence || @template.complementary_prompt,
                                                           inbox: inbox)
    return render json: { error: 'empty' }, status: :unprocessable_entity if estado.nil?

    render json: estado, status: :accepted
  end

  def compare
    version = @template.versions.find(params[:version_id])
    estado = TestCases.run_compare(Current.account, @template, version: version, inbox: inbox,
                                                               draft: params[:draft].presence || @template.complementary_prompt)
    return render json: { error: 'empty' }, status: :unprocessable_entity if estado.nil?

    render json: estado, status: :accepted
  end

  def run_live
    if ContactTrackings::Assistant::TestBattery.sandbox_inbox(Current.account).nil?
      return render json: { error: 'no_sandbox' }, status: :unprocessable_entity
    end

    id = TestCases.run_live(Current.account, @template, case_ids: params[:case_ids])
    return render json: { error: 'empty' }, status: :unprocessable_entity if id.nil?

    render json: { id: id }, status: :accepted
  end

  private

  def case_json(caso)
    { id: caso.id, message: caso.message, kind: caso.kind, expected_route: caso.expected_route, rule: caso.rule,
      pinned: caso.pinned, turns: caso.turns, last_dry: caso.last_dry, previous_dry: caso.previous_dry,
      last_live: caso.last_live, previous_live: caso.previous_live, dry_changed: caso.dry_changed? }
  end

  def pile_json
    candidatos = TestCases.live_candidates(@template)
    { cases: @template.test_cases.ordered.map { |c| case_json(c) },
      dry_run: TestCases.dry_status(@template),
      compare: TestCases.compare_status(@template),
      live_offer: { case_ids: candidatos.map(&:id), tokens: TestCases.estimate_tokens(@template, candidatos),
                    max: TestCases::MAX_LIVE_OFFER } }
  end

  def fetch_template
    @template = Current.account.tracking_templates.find(params[:template_id])
  end

  def fetch_case
    @case = TrackingTestCase.find_by!(id: params[:id], account_id: Current.account.id)
  end

  def inbox
    return @template.inbox if params[:inbox_id].blank?

    Current.account.inboxes.find_by(id: params[:inbox_id])
  end

  def check_authorization
    render json: { error: I18n.t('errors.unauthorized') }, status: :unauthorized unless Current.account_user&.administrator?
  end
end

class Api::V1::Accounts::AgentsController < Api::V1::Accounts::BaseController
  before_action :fetch_agent, except: [:create, :index, :bulk_create]
  before_action :check_authorization
  before_action :validate_limit, only: [:create]
  before_action :validate_limit_for_bulk_create, only: [:bulk_create]

  def index
    @agents = agents
  end

  def create
    builder = AgentBuilder.new(
      email: new_agent_params['email'],
      name: new_agent_params['name'],
      role: new_agent_params['role'],
      availability: new_agent_params['availability'],
      auto_offline: new_agent_params['auto_offline'],
      inviter: current_user,
      account: Current.account
    )

    @agent = builder.perform
  end

  # def update
  #   @agent.update!(agent_params.slice(:name).compact)
  #   @agent.current_account_user.update!(agent_params.slice(*account_user_attributes).compact)
  # end

  def update
    @agent.update!(agent_params.slice(:name, :custom_attributes).compact)
    @agent.current_account_user.update!(agent_params.slice(*account_user_attributes).compact.merge(access_role_attributes))
  end

  def destroy
    @agent.current_account_user.destroy!
    delete_user_record(@agent)
    head :ok
  end

  def bulk_create
    emails = params[:emails]

    emails.each do |email|
      builder = AgentBuilder.new(
        email: email,
        name: email.split('@').first,
        inviter: current_user,
        account: Current.account
      )
      begin
        builder.perform
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.info "[Agent#bulk_create] ignoring email #{email}, errors: #{e.record.errors}"
      end
    end

    # This endpoint is used to bulk create agents during onboarding
    # onboarding_step key in present in Current account custom attributes, since this is a one time operation
    Current.account.custom_attributes.delete('onboarding_step')
    Current.account.save!
    head :ok
  end

  private

  def check_authorization
    super(User)
  end

  def fetch_agent
    @agent = agents.find(params[:id])
  end

  # def account_user_attributes
  #   [:role, :availability, :auto_offline]
  # end
  def account_user_attributes
    # ================================================================================
    # proyecto@user_contact
    # ================================================================================
    [:role, :availability, :auto_offline, :agent_contact_id]
    # ================================================================================
  end

  # def allowed_agent_params
  #   [:name, :email, :name, :role, :availability, :auto_offline, custom_attributes: {}]
  # end
  def allowed_agent_params
    # ================================================================================
    # proyecto@user_contact
    # ================================================================================
    [:name, :email, :name, :role, :availability, :auto_offline, :agent_contact_id, custom_attributes: {}]
    # ================================================================================
  end

  def agent_params
    params.require(:agent).permit(allowed_agent_params)
  end

  # Plan-Roles-Permisos — el combo «Rol» manda la clave (supervisor, seller…).
  # Plan-Trabajo-Campo R3 — y el perfil de campo (habilidades y zona).
  def access_role_attributes
    attrs = field_profile_attributes
    key = params.dig(:agent, :access_role_key).presence
    return attrs unless key

    role = AccessRole.for_account(Current.account).find { |access_role| access_role.key == key }
    role ? attrs.merge(access_role: role) : attrs
  end

  def field_profile_attributes
    profile = params.dig(:agent, :field_profile)
    return {} unless profile

    { field_profile: { 'skills' => Array(profile[:skills]).map(&:to_s).compact_blank, 'zone' => profile[:zone].to_s.strip.presence }.compact }
  end

  def new_agent_params
    params.require(:agent).permit(:email, :name, :role, :availability, :auto_offline)
  end

  def agents
    @agents ||= Current.account.users.order_by_full_name.includes(:account_users, { avatar_attachment: [:blob] })
  end

  def validate_limit_for_bulk_create
    limit_available = params[:emails].count <= available_agent_count

    render_payment_required('Account limit exceeded. Please purchase more licenses') unless limit_available
  end

  def validate_limit
    render_payment_required('Account limit exceeded. Please purchase more licenses') unless can_add_agent?
  end

  def available_agent_count
    Current.account.usage_limits[:agents] - agents.count
  end

  def can_add_agent?
    available_agent_count.positive?
  end

  def delete_user_record(agent)
    DeleteObjectJob.perform_later(agent) if agent.reload.account_users.blank?
  end
end

Api::V1::Accounts::AgentsController.prepend_mod_with('Api::V1::Accounts::AgentsController')

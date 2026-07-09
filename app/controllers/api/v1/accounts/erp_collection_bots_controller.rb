# frozen_string_literal: true

# @query_databases — CRUD de bots cobradores (solo admin).
class Api::V1::Accounts::ErpCollectionBotsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :fetch_bot, only: [:show, :update, :destroy, :preview]

  def index
    render json: Current.account.erp_collection_bots.order(:name).map { |b| bot_json(b) }
  end

  def show
    render json: bot_json(@bot)
  end

  def create
    @bot = Current.account.erp_collection_bots.new(bot_params)
    @bot.save!
    render json: bot_json(@bot), status: :created
  end

  def update
    @bot.update!(bot_params)
    render json: bot_json(@bot)
  end

  def destroy
    @bot.destroy!
    head :ok
  end

  # Vista previa de los recordatorios (dry-run, sin enviar).
  def preview
    render json: { messages: ErpCollection::ReminderService.new(@bot).preview(limit: 5) }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def fetch_bot
    @bot = Current.account.erp_collection_bots.find(params[:id])
  end

  def bot_params
    params.require(:erp_collection_bot)
          .permit(:name, :external_db_connection_id, :external_db_query_id, :inbox_id,
                  :message_template, :phone_column, :run_hour, :mode_b_enabled, :active)
  end

  def bot_json(bot)
    {
      id: bot.id,
      name: bot.name,
      external_db_connection_id: bot.external_db_connection_id,
      external_db_query_id: bot.external_db_query_id,
      inbox_id: bot.inbox_id,
      message_template: bot.message_template,
      phone_column: bot.phone_column,
      run_hour: bot.run_hour,
      mode_b_enabled: bot.mode_b_enabled,
      active: bot.active,
      last_run_at: bot.last_run_at
    }
  end
end

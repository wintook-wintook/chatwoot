# frozen_string_literal: true

# Academia Kontrolya — «Mi capacitación» (Inicio). Cada quien ve y mueve solo su avance.
#   GET    …/academy                                   → módulos de su rol, pasos y cómo va (Academy::Board)
#   POST   …/academy/steps/:module_key/:step_key/start → «Leer» (lección leída) o «Hazlo» (empieza a contar)
#   POST   …/academy/steps/:module_key/:step_key/check → «Revisar»: { step, found, message }
#   GET    …/academy/guides/:key                       → el texto de la guía de una lección
#   POST   …/academy/practice                          → crea su Cliente de práctica
#   DELETE …/academy/practice                          → lo borra con lo que hizo en él
class Api::V1::Accounts::AcademyController < Api::V1::Accounts::BaseController
  rescue_from Academy::Board::NotFound do |e|
    render json: { error: e.message }, status: :not_found
  end

  def show
    render json: board.call
  end

  def start
    render json: { step: board.start(params[:module_key], params[:step_key]) }
  end

  def check
    render json: board.check(params[:module_key], params[:step_key])
  end

  def guide
    guide = Assistant::Guides.find(params[:key], access_grant)
    return render json: { error: 'Esa guía no existe' }, status: :not_found unless guide

    render json: { key: guide.key, title: guide.title, content: guide.body,
                   url: Assistant::GuidePublisher.article_url(guide.key) }.compact
  end

  def create_practice
    Academy::Practice.new(Current.account, current_user).create!
    render json: board.call
  end

  def destroy_practice
    Academy::Practice.new(Current.account, current_user).destroy!
    render json: board.call
  end

  private

  def board
    @board ||= Academy::Board.new(account: Current.account, user: current_user, grant: access_grant)
  end
end

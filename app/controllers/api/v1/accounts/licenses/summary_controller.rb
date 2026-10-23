# feat/licencias (F4) — GET …/licenses/summary: los números del tablero (Licenses::Summary).
# Misma puerta que el resto de la gestión: cuenta de Wintook + «Ver licencias».
class Api::V1::Accounts::Licenses::SummaryController < Api::V1::Accounts::Licenses::BaseController
  def show
    render json: Licenses::Summary.new.call
  end
end

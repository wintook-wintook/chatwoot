# frozen_string_literal: true

# Catálogo semántico FIJO (solo lectura) para el <select> de la palabra raíz.
class Api::V1::Accounts::SinonimosSemanticosController < Api::V1::Accounts::BaseController
  def index
    render json: SinonimoSemantico.order(:id).map { |s| { id: s.id, nombre: s.nombre } }
  end
end

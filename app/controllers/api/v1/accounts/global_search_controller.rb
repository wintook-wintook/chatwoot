# frozen_string_literal: true

# Buscar en todo — la lupa de la barra de arriba (QuickSearchModal).
#   GET …/global_search?q=compresor                 → los primeros de cada grupo
#   GET …/global_search?q=compresor&type=cases&page=2 → «ver más» de un grupo
# Contactos, organizaciones y casos; con los permisos de quien busca (GlobalSearch).
class Api::V1::Accounts::GlobalSearchController < Api::V1::Accounts::BaseController
  def index
    render json: GlobalSearch.new(account: Current.account, grant: access_grant, query: params[:q],
                                  type: params[:type], page: params[:page]).call
  end
end

class CustomFilterPolicy < ApplicationPolicy
  def create?
    member?
  end

  def index?
    member?
  end

  # A partir de @tickets_cases F2 estas tres se autorizan contra el REGISTRO, no
  # contra la clase: el indice ahora incluye vistas compartidas por otros, y sin
  # esta comprobacion cualquier agente podria editar o borrar la vista ajena que
  # acaba de aparecerle en la lista.
  def show?
    member?
  end

  def update?
    member? && editable?
  end

  def destroy?
    member? && editable?
  end

  private

  def member?
    @account_user.administrator? || @account_user.agent?
  end

  # Su dueno siempre. Un administrador solo sobre las compartidas: las personales
  # de otro agente no son suyas para tocar, aunque sea administrador.
  def editable?
    @record.owned_by?(@account_user.user) || (@account_user.administrator? && @record.shared?)
  end
end

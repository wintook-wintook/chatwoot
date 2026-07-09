# @waba_templates — gestión de plantillas de WhatsApp (solo administradores de la cuenta).
class WhatsappTemplatePolicy < ApplicationPolicy
  def index?
    @account_user.administrator?
  end

  def show?
    @account_user.administrator?
  end

  def create?
    @account_user.administrator?
  end

  def update?
    @account_user.administrator?
  end

  def destroy?
    @account_user.administrator?
  end

  def sync?
    @account_user.administrator?
  end
end

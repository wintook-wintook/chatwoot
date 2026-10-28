class ContactPolicy < ApplicationPolicy
  def index?
    true
  end

  def active?
    true
  end

  def import?
    @account_user.administrator?
  end

  # Plan-Roles-Permisos — también los roles con «exportar» y acceso a Clientes.
  def export?
    return true if @account_user.administrator?

    grant = @account_user.access_grant
    grant.can?(:export) && grant.allowed?(:clients)
  end

  def search?
    true
  end

  def filter?
    true
  end

  def update?
    true
  end

  def contactable_inboxes?
    true
  end

  def destroy_custom_attributes?
    true
  end

  def show?
    true
  end

  def create?
    true
  end

  def avatar?
    true
  end

  def destroy?
    @account_user.administrator?
  end
end

class ReportPolicy < ApplicationPolicy
  # Plan-Roles-Permisos — también los roles con el área Informes.
  def view?
    @account_user.administrator? || @account_user.access_grant.allowed?(:reports)
  end
end

ReportPolicy.prepend_mod_with('Enterprise::ReportPolicy')

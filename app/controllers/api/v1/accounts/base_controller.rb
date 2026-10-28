class Api::V1::Accounts::BaseController < Api::BaseController
  include SwitchLocale
  include EnsureCurrentAccountHelper
  before_action :current_account
  include AccessAreaGuard # Plan-Roles-Permisos — después de current_account (usa Current.account_user)
  around_action :switch_locale_using_account_locale
end

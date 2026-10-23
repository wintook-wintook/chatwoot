# feat/licencias (F3) — el aviso de que la licencia de la cuenta está por vencer. Los textos
# salen de I18n en el idioma de la cuenta (ApplicationMailer#switch_locale).
class AdministratorNotifications::LicenseNotificationsMailer < ApplicationMailer
  def expiring(license, days)
    return unless smtp_config_set_or_development?

    # dd/mm/aaaa: el español del proyecto no trae date.formats.long y I18n.l fallaría.
    fecha = license.expires_at.in_time_zone.strftime('%d/%m/%Y')
    @action_url = "#{ENV.fetch('FRONTEND_URL', nil)}/app/accounts/#{Current.account.id}/dashboard"
    @meta = {
      'greeting' => I18n.t('licenses.mailer.greeting'),
      'body' => I18n.t('licenses.mailer.expiring_body', plan: license.name, account: Current.account.name, days: days, date: fecha),
      'after' => I18n.t('licenses.mailer.expiring_after'),
      'cta' => I18n.t('licenses.mailer.cta')
    }
    send_mail_with_liquid(to: Current.account.administrators.pluck(:email),
                          subject: I18n.t('licenses.mailer.expiring_subject', days: days)) and return
  end

  private

  def liquid_locals
    super.merge({ meta: @meta })
  end
end

json.partial! 'api/v1/models/account', formats: [:json], resource: @account
json.latest_chatwoot_version @latest_chatwoot_version
json.license @account.license_summary # feat/licencias (F5): nil = fuera de licencia
json.partial! 'enterprise/api/v1/accounts/partials/account', account: @account if ChatwootApp.enterprise?

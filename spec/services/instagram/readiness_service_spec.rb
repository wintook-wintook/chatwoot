require 'rails_helper'

RSpec.describe Instagram::ReadinessService do
  let!(:account) { create(:account) }

  # .env de esta instalación declara IG_VERIFY_TOKEN vacío, y ENV gana sobre la BD.
  # Los tests fijan la variable de entorno para reproducir una instalación bien configurada.
  def set_config(name, value)
    InstallationConfig.find_or_initialize_by(name: name).update!(value: value)
    ENV[name] = value
    GlobalConfig.clear_cache
  end

  around do |example|
    originals = %w[INSTAGRAM_APP_ID INSTAGRAM_APP_SECRET IG_VERIFY_TOKEN].index_with { |name| ENV.fetch(name, nil) }
    example.run
    originals.each do |name, value|
      InstallationConfig.find_by(name: name)&.update!(value: nil)
      ENV[name] = value
    end
    GlobalConfig.clear_cache
  end

  describe '#ready?' do
    it 'is not ready while the credentials are missing' do
      %w[INSTAGRAM_APP_ID INSTAGRAM_APP_SECRET IG_VERIFY_TOKEN].each { |name| set_config(name, nil) }

      service = described_class.new

      expect(service).not_to be_ready
      expect(service.checks.reject(&:ok).map(&:name)).to include('INSTAGRAM_APP_ID', 'INSTAGRAM_APP_SECRET', 'IG_VERIFY_TOKEN')
    end

    it 'is ready once everything is configured' do
      set_config('INSTAGRAM_APP_ID', 'ig-app-id')
      set_config('INSTAGRAM_APP_SECRET', 'ig-app-secret')
      set_config('IG_VERIFY_TOKEN', 'verify-token')

      expect(described_class.new).to be_ready
    end

    it 'never exposes the app secret, only whether it is set' do
      set_config('INSTAGRAM_APP_SECRET', 'super-secret-value')

      details = described_class.new.checks.map(&:detail).join(' ')

      expect(details).not_to include('super-secret-value')
    end
  end

  describe 'account flag' do
    before do
      set_config('INSTAGRAM_APP_ID', 'ig-app-id')
      set_config('INSTAGRAM_APP_SECRET', 'ig-app-secret')
      set_config('IG_VERIFY_TOKEN', 'verify-token')
    end

    it 'reports the flag as missing when the account does not have it' do
      service = described_class.new(account: account)

      expect(service).not_to be_ready
      expect(service.checks.reject(&:ok).map(&:name).join).to include('channel_instagram')
    end

    it 'is ready when the account has the flag enabled' do
      account.enable_features!('channel_instagram')

      expect(described_class.new(account: account)).to be_ready
    end
  end

  describe 'config shadowed by an empty .env entry' do
    it 'warns when Super Admin has a value but .env declares the key empty' do
      InstallationConfig.find_or_initialize_by(name: 'INSTAGRAM_APP_ID').update!(value: 'set-in-super-admin')
      ENV['INSTAGRAM_APP_ID'] = ''
      GlobalConfig.clear_cache

      shadowed = described_class.new.checks.find { |c| c.name.include?('anulado por .env') }

      expect(shadowed).to be_present
      expect(shadowed.name).to include('INSTAGRAM_APP_ID')
    end
  end

  describe '#channels' do
    it 'reports how many days each token has left' do
      create(:channel_instagram, account: account, expires_at: 30.days.from_now)

      row = described_class.new.channels.last

      expect(row[:days_left]).to eq(30)
      expect(row[:reauthorization_required]).to be false
    end

    it 'flags channels that need reauthorization' do
      channel = create(:channel_instagram, account: account)
      channel.prompt_reauthorization!

      expect(described_class.new.channels.last[:reauthorization_required]).to be true
    end
  end
end

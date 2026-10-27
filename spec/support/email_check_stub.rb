# prospeccion V7a: las pruebas no consultan DNS. Todo dominio «recibe correo», salvo que
# el spec diga otra cosa (spec/services/contact_trackings/email_check_spec.rb).
RSpec.configure do |config|
  config.before do
    allow(ContactTrackings::EmailCheck).to receive(:lookup).and_return(true)
  end
end

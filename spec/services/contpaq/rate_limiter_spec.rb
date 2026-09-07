# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Contpaq::RateLimiter do
  let(:account) { create(:account) }
  let(:source)  { account.knowledge_sources.create!(name: 'Agente CONTPAQi', source_type: 'contpaq_support') }

  def bucket_key
    format(Redis::RedisKeys::CONTPAQ_RATE_BUCKET,
           source_id: source.id, minute: Time.now.utc.strftime('%Y%m%d%H%M'))
  end

  after { Redis::Alfred.delete(bucket_key) }

  it 'deja pasar hasta el limite y corta despues' do
    limiter = described_class.new(source, limit: 3)

    expect(Array.new(3) { limiter.allow? }).to all(be(true))
    expect(limiter.allow?).to be(false)
  end

  it 'le pone vencimiento al contador, para que no bloquee para siempre' do
    allow(Redis::Alfred).to receive(:set).and_call_original
    described_class.new(source, limit: 3).allow?

    # nx: solo el primero lo crea; ex: nadie queda con un contador sin vencimiento.
    expect(Redis::Alfred).to have_received(:set)
      .with(bucket_key, 0, nx: true, ex: described_class::BUCKET_TTL)
  end

  it 'cuenta por minuto de reloj: el minuto siguiente arranca limpio' do
    limiter = described_class.new(source, limit: 1)
    expect(limiter.allow?).to be(true)
    expect(limiter.allow?).to be(false)

    travel_to(Time.now.utc + 61.seconds) do
      expect(described_class.new(source, limit: 1).allow?).to be(true)
    end
  end

  it 'el contador es por fuente, no global' do
    otra = account.knowledge_sources.create!(name: 'Otro CONTPAQi', source_type: 'contpaq_support')
    expect(described_class.new(source, limit: 1).allow?).to be(true)
    expect(described_class.new(source, limit: 1).allow?).to be(false)
    expect(described_class.new(otra, limit: 1).allow?).to be(true)

    Redis::Alfred.delete(format(Redis::RedisKeys::CONTPAQ_RATE_BUCKET,
                                source_id: otra.id, minute: Time.now.utc.strftime('%Y%m%d%H%M')))
  end

  it 'si Redis no responde deja pasar: un limitador caido no apaga la fuente' do
    allow(Redis::Alfred).to receive(:set).and_raise(Redis::CannotConnectError)
    expect(described_class.new(source).allow?).to be(true)
  end
end

# frozen_string_literal: true

RSpec.describe Clepsydra::TokenProvider do
  subject(:provider) { described_class }

  it 'generates token using [0-9a-z]' do
    expect(provider.generate).to match(/[a-z0-9]{10}/)
  end

  it 'generates token of length 10 chars long' do
    expect(provider.generate.length).to eq(10)
  end

  it 'generates unique token' do
    tokens = Set.new

    100_000.times { tokens << provider.generate }

    expect(tokens.length).to eq(100_000)
    expect(tokens).to all(match(/[a-z0-9]{10}/))
    expect(tokens.map(&:length)).to all(eq(10))
  end
end

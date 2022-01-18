# frozen_string_literal: true

RSpec.describe Clepsydra::Version do
  it 'has correct value' do
    expect(described_class::VALUE).to eq('0.0.1')
  end
end

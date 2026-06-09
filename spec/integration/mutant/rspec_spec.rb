# frozen_string_literal: true

RSpec.describe 'rspec integration', mutant: false do
  versions = if ENV.key?('MUTANT_RSPEC_VERSION')
               [ENV.fetch('MUTANT_RSPEC_VERSION')]
             else
               %w[3.10 3.13 4.0]
             end

  let(:base_cmd) do
    %w[bundle exec mutant run -I lib --require ./config/environment --use rspec]
  end

  versions.each do |version|
    context "RSpec #{version}" do
      let(:gemfile) { "Gemfile.rspec#{version}" }

      it_behaves_like 'framework integration'
    end
  end
end

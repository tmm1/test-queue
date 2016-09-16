require "rspec"

describe 'SplittableGroup', :no_split => !!ENV["NOSPLIT"] do
  2.times do |i|
    it "runs test #{i}" do
      # Sleep longer in CI to make the distribution of examples across workers
      # more deterministic.
      if ENV["CI"]
        sleep(5)
      else
        sleep(1)
      end

      expect(1).to eq 1
    end
  end
end

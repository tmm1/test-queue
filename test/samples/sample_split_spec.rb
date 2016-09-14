require "rspec"

describe 'SplittableGroup' do
  it 'runs one test' do
    # Sleep longer in CI to make the distribution of examples across workers
    # more deterministic.
    if ENV["CI"]
      sleep(5)
    else
      sleep(1)
    end

    expect(1).to eq 1
  end

  it 'runs another test' do
    expect(2).to eq 2
  end
end

describe 'UnsplittableGroup', :no_split => true do
  it 'runs one test' do
    expect(1).to eq 1
  end

  it 'runs another test' do
    expect(2).to eq 2
  end
end

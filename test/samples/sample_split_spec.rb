require "rspec"

describe 'SplittableGroup' do
  it 'runs one test' do
    sleep(1)
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

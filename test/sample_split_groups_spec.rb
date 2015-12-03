require 'rspec'

# given 3 workers, 2 will finish at almost exactly the same time when
# using TEST_QUEUE_SPLIT_GROUPS=1; 1 worker will run a bit longer due to
# the no_split tag

describe "MediumSlowGroup" do
  5.times do |i|
    it "test #{i}" do
      sleep(0.25)
      expect(1).to eq 1
    end
  end
end

describe "BigSlowGroup" do
  group_run_count = 0
  before :all do
    sleep(1)
    group_run_count += 1
    # should never run more than once per worker
    expect(group_run_count).to eq 1
  end

  20.times do |i|
    it "test #{i}" do
      sleep(0.25)
      expect(1).to eq 1
    end
  end

  describe "NestedSlowGroup" do
    10.times do |i|
      it "test #{i}" do
        sleep(0.25)
        expect(1).to eq 1
      end
    end
  end
end

describe "NoSplitGroup", no_split: true do
  30.times do |i|
    it "test #{i}" do
      sleep(0.25)
      expect(1).to eq 1
    end
  end
end

require "fileutils"
require "tempfile"
require "test_queue/stats"

RSpec.describe TestQueue::Stats do
  before do
    Tempfile.open("test_queue_stats") do |f|
      @path = f.path
      f.close!
    end
  end

  after do
    FileUtils.rm_f(@path)
  end

  describe "#initialize" do
    it "ignores empty stats files" do
      File.write(@path, "")
      stats = TestQueue::Stats.new(@path)
      expect(stats.all_suites).to be_empty
    end

    it "ignores invalid data in the stats files" do
      File.write(@path, "this is not marshal data")
      stats = TestQueue::Stats.new(@path)
      expect(stats.all_suites).to be_empty
    end

    it "ignores badly-typed data in the stats file" do
      File.write(@path, Marshal.dump(["heyyy"]))
      stats = TestQueue::Stats.new(@path)
      expect(stats.all_suites).to be_empty
    end

    it "ignores stats files with a wrong version number" do
      File.write(@path, Marshal.dump({ :version => 1e8, :suites => "boom" }))
      stats = TestQueue::Stats.new(@path)
      expect(stats.all_suites).to be_empty
    end
  end

  it "can save and load data" do
    stats = TestQueue::Stats.new(@path)
    time = truncated_now
    suites = [
      TestQueue::Stats::Suite.new("Suite1", "foo.rb", 0.3, time),
      TestQueue::Stats::Suite.new("Suite2", "bar.rb", 0.5, time + 5),
    ]
    stats.record_suites(suites)
    stats.save

    stats = TestQueue::Stats.new(@path)
    expect(stats.all_suites.sort_by(&:name)).to eq(suites)
  end

  it "prunes suites not seen in the last 8 days" do
    stats = TestQueue::Stats.new(@path)
    time = truncated_now
    suites = [
      TestQueue::Stats::Suite.new("Suite1", "foo.rb", 0.3, time),
      TestQueue::Stats::Suite.new("Suite2", "bar.rb", 0.5, time - (8 * 24 * 60 * 60) - 2),
      TestQueue::Stats::Suite.new("Suite3", "baz.rb", 0.6, time - (7 * 24 * 60 * 60)),
    ]
    stats.record_suites(suites)
    stats.save

    stats = TestQueue::Stats.new(@path)
    expect(stats.all_suites.map(&:name).sort).to eq(%w[Suite1 Suite3])
  end

  # Returns Time.now rounded down to the nearest second.
  def truncated_now
    Time.at(Time.now.to_i)
  end
end

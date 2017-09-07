Then(/^covered$/) do
  require_relative '../../coverage'
  TestClass.new.test.should == 'test'
end

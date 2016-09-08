Given(/^a$/) do
  sleep 0.10
end

When(/^b$/) do
  sleep 0.25
end

When(/^bad$/) do
  if ENV["FAIL"]
    1.should == 0
  else
    1.should == 1
  end
end

Then(/^c$/) do
  1.should == 1
end

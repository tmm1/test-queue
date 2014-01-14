Given(/^a$/) do
  sleep 0.10
end

When(/^b$/) do
  sleep 0.25
end

When(/^bad$/) do
  1.should == 0
end

Then(/^c$/) do
  1.should == 1
end

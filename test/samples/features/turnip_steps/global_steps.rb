step %(a) do
  1.should == 1
end

step %(b) do
  1.should == 1
end

step %(bad) do
  if ENV["FAIL"]
    1.should == 0
  else
    1.should == 1
  end
end

step %(c) do
  1.should == 1
end

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe "/opportunities/index.html.erb" do
  include OpportunitiesHelper
  
  before(:each) do
    login_and_assign
    assign(:stage, Setting.unroll(:opportunity_stage))
  end

  it "should render list of accounts if list of opportunities is not empty" do
    assign(:opportunities, [ Factory(:opportunity) ].paginate)
    view.should render_template(:partial => "_opportunity")
    view.should_receive(:render).with(:partial => "common/paginate")
    render
  end

  it "should render a message if there're no opportunities" do
    assign(:opportunities, [].paginate)
    view.should_not_receive(:render).with(hash_including(:partial => "opportunities"))
    view.should_receive(:render).with(:partial => "common/empty")
    view.should_receive(:render).with(:partial => "common/paginate")
    render
  end

end


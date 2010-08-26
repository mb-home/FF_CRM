require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')
 
describe "/campaigns/update.js.rjs" do
  include CampaignsHelper
  
  before(:each) do
    login_and_assign
    assigns[:campaign] = @campaign = Factory(:campaign, :user => @current_user)
    assigns[:users] = [ @current_user ]
    assigns[:status] = Setting.campaign_status
    assigns[:campaign_status_total] = { :called_off => 1, "Explicit" => 1 }
  end
 
  describe "no errors:" do
    describe "on landing page -" do
      before(:each) do
        controller.request.env["HTTP_REFERER"] = "http://localhost/campaigns/123"
      end
      
      it "should flip [edit_campaign] form" do
        render
        rendered.should_not have_rjs("campaign_#{@campaign.id}")
        rendered.should include_text('crm.flip_form("edit_campaign"')
      end
  
      it "should update sidebar" do
        render
        rendered.should have_rjs("sidebar") do |rjs|
          with_tag("div[id=summary]")
          with_tag("div[id=recently]")
        end
        rendered.should include_text('$("summary").visualEffect("shake"')
      end
    end

    describe "on index page -" do
      before(:each) do
        controller.request.env["HTTP_REFERER"] = "http://localhost/campaigns"
      end

      it "should replace [Edit Campaign] with campaign partial and highligh it" do
        render
        rendered.should have_rjs("campaign_#{@campaign.id}") do |rjs|
          with_tag("li[id=campaign_#{@campaign.id}]")
        end
        rendered.should include_text(%Q/$("campaign_#{@campaign.id}").visualEffect("highlight"/)
      end
    end
  end # no errors

  describe "validation errors:" do
    describe "on landing page -" do
      before(:each) do
        @campaign.errors.add(:error)
        controller.request.env["HTTP_REFERER"] = "http://localhost/campaigns/123"
      end

      it "should redraw the [edit_campaign] form and shake it" do
        render
        rendered.should have_rjs("edit_campaign") do |rjs|
          with_tag("form[class=edit_campaign]")
        end
        rendered.should include_text('crm.date_select_popup("campaign_starts_on")')
        rendered.should include_text('crm.date_select_popup("campaign_ends_on")')
        rendered.should include_text('$("edit_campaign").visualEffect("shake"')
        rendered.should include_text('focus()')
      end
    end

    describe "on index page -" do
      before(:each) do
        @campaign.errors.add(:error)
        controller.request.env["HTTP_REFERER"] = "http://localhost/campaigns"
      end
    
      it "should redraw the [edit_campaign] form and shake it" do
        render
        rendered.should have_rjs("campaign_#{@campaign.id}") do |rjs|
          with_tag("form[class=edit_campaign]")
        end
        rendered.should include_text('crm.date_select_popup("campaign_starts_on")')
        rendered.should include_text('crm.date_select_popup("campaign_ends_on")')
        rendered.should include_text(%Q/$("campaign_#{@campaign.id}").visualEffect("shake"/)
        rendered.should include_text('focus()')
      end
    end
  end # errors
end
require "./spec_helper"
require "sqlite3"
require "crumble/spec/test_request_context"

TEST_DB_CONNECTION_STRING = "sqlite3:%3Amemory%3A?max_pool_size=1"

abstract class TestRecord < Orma::Record
  macro inherited
    {% unless @type.abstract? %}
      self.continuous_migration!
    {% end %}
  end

  def self.db_connection_string
    TEST_DB_CONNECTION_STRING
  end
end

module HotCrumbleSpec
  class WelcomePage < Crumble::Page
    view do
      template do
        html do
          body do
            h1 { "Welcome from crumble" }
          end
        end
      end
    end
  end

  class PingAction < Crumble::Turbo::Action
    controller do
      action_template.turbo_stream.to_html(ctx.response)
    end

    view do
      template do
        action_form(hidden: false).to_html do
          button { "Ping" }
        end
      end
    end
  end

  class Counter < TestRecord
    id_column id : Int64
    column count : Int32 = 0

    model_template :count_view do
      div { count }
    end

    model_action :increment, count_view do
      controller do
        model.update(count: model.count.value + 1)
      end

      view do
        template do
          custom_action_trigger.to_html do
            button { "Increment" }
          end
        end
      end
    end
  end

  class ClipboardController < Stimulus::Controller
    values message: String
    targets :output

    action :copy do
    end
  end
end

describe "hot-crumble integration" do
  it "renders a crumble page" do
    response = String.build do |io|
      ctx = Crumble::Server::TestRequestContext.new(response_io: io, method: "GET", resource: HotCrumbleSpec::WelcomePage.uri_path)
      HotCrumbleSpec::WelcomePage.handle(ctx).should be_true
      ctx.response.flush
    end

    response.should contain("<h1>Welcome from crumble</h1>")
  end

  it "handles a crumble-turbo action" do
    response = String.build do |io|
      ctx = Crumble::Server::TestRequestContext.new(response_io: io, method: "POST", resource: HotCrumbleSpec::PingAction.uri_path)
      HotCrumbleSpec::PingAction.handle(ctx).should be_true
      ctx.response.flush
    end

    response.should contain("<turbo-stream")
    response.should contain("Ping")
  end

  it "handles a crumble-turbo model action" do
    counter = HotCrumbleSpec::Counter.create(count: 1)
    ctx = Crumble::Server::TestRequestContext.new(method: "POST", resource: HotCrumbleSpec::Counter::IncrementAction.uri_path(counter.id.value))
    HotCrumbleSpec::Counter::IncrementAction.handle(ctx).should be_true

    HotCrumbleSpec::Counter.find(counter.id.value).count.value.should eq(2)
  end

  it "builds a stimulus controller" do
    controller_name = HotCrumbleSpec::ClipboardController.controller_name
    HotCrumbleSpec::ClipboardController.message_value("Copied").attr_name.should eq("data-#{controller_name}-message-value")
    HotCrumbleSpec::ClipboardController.output_target.attr_name.should eq("data-#{controller_name}-target")
    HotCrumbleSpec::ClipboardController.copy_action("click").attr_value.should eq("click->#{controller_name}#copy")
  end
end

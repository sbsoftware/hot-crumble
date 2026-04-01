require "./spec_helper"
require "sqlite3"
require "uri"
require "crumble/spec/test_handler_context"
require "crumble/spec/test_request_context"

TEST_DB_CONNECTION_STRING = "sqlite3:%3Amemory%3A?max_pool_size=1"
Orma.db_connection_string = TEST_DB_CONNECTION_STRING

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
  style AppStyle do
    rule body do
      font_size 14.px
    end
  end

  class ApplicationLayout < ToHtml::Layout
  end

  class WelcomePage < Crumble::Page
    template do
      html do
        body do
          h1 { "Welcome from crumble" }
        end
      end
    end
  end

  class StyledPage < Crumble::Page
    template do
      main do
        h2 { "Styled from crumble" }
      end
    end

    layout ApplicationLayout
  end

  class LocalizedGreeting
    include Crumble::Crababel

    getter ctx : Crumble::Server::HandlerContext

    def initialize(@ctx : Crumble::Server::HandlerContext)
    end

    def message
      t
    end
  end

  class LocalizedPage < Crumble::Page
    template do
      html do
        body do
          h1 { HotCrumbleSpec::LocalizedGreeting.new(ctx).message }
        end
      end
    end
  end

  class LocalizedForm < Crumble::Form
    field email : String
  end

  class Article < TestRecord
    id_column id : Int64
    column title : String
  end

  class MissingArticleView
    include Crumble::ContextView

    template do
      p { "Article not found" }
    end
  end

  class ArticlePage < Crumble::Page
    model article : Article, fallback_view: MissingArticleView

    template do
      p { article.title }
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

  class AuditJob < Crumble::Jobs::Job
    params message : String, count : Int32

    @@runs = [] of String

    def perform : Nil
      @@runs << "#{@message}|#{@count}"
    end

    def self.runs : Array(String)
      @@runs
    end

    def self.clear : Nil
      @@runs.clear
    end
  end

  class RetryableAuditError < Exception
  end

  class RetryingAuditJob < Crumble::Jobs::Job
    retry_on RetryableAuditError, attempts: 1, wait: ->(attempt : Int32) { 10.milliseconds }
    params token : String

    @@runs = [] of String

    def perform : Nil
      @@runs << @token
      raise RetryableAuditError.new("retry #{@token}") if @@runs.size == 1
    end

    def self.runs : Array(String)
      @@runs
    end

    def self.clear : Nil
      @@runs.clear
    end
  end

  class EnqueueJobAction < Crumble::Turbo::Action
    controller do
      HotCrumbleSpec::AuditJob.enqueue(message: "from action", count: 2)
      action_template.turbo_stream.to_html(ctx.response)
    end

    view do
      template do
        action_form(hidden: false).to_html do
          button { "Enqueue" }
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

  class EditableCounter < TestRecord
    id_column id : Int64
    column count : Int32 = 0

    model_template :count_view do
      div { count }
    end

    model_action :set_count, count_view do
      form do
        field value : Int32, label: "Count", type: :select, allow_blank: false, options: count_options

        def count_options
          [{"", "Pick a count"}, {model.count.value.to_s, "Current #{model.count.value}"}]
        end
      end

      controller do
        model.update(count: form.value.not_nil!) if form.valid?
      end

      view do
        template do
          action_form(hidden: false).to_html do
            if errors = action.form.errors
              div class: "errors" do
                errors.join(",")
              end
            end

            button { "Set Count" }
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

  it "renders stylesheet assets through the shared layout" do
    response = String.build do |io|
      ctx = Crumble::Server::TestRequestContext.new(response_io: io, method: "GET", resource: HotCrumbleSpec::StyledPage.uri_path)
      HotCrumbleSpec::StyledPage.handle(ctx).should be_true
      ctx.response.flush
    end

    response.should contain(%(href="#{HotCrumbleSpec::AppStyle.uri_path}"))
    AssetFileRegistry.query(HotCrumbleSpec::AppStyle.uri_path).not_nil!.contents.should eq("body {\n  font-size: 14px;\n}")
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

  it "renders model-aware action form options from crumble-orma models" do
    counter = HotCrumbleSpec::EditableCounter.new(id: 8_i64, count: 4)
    ctx = Crumble::Server::TestRequestContext.new

    counter.set_count_action_template(ctx).to_html.should contain(%(<option value="4">Current 4</option>))
  end

  it "updates models from model-aware crumble-turbo action forms" do
    counter = HotCrumbleSpec::EditableCounter.create(count: 1)
    ctx = Crumble::Server::TestRequestContext.new(method: "POST", resource: HotCrumbleSpec::EditableCounter::SetCountAction.uri_path(counter.id.value), body: URI::Params.encode({value: "5"}))
    HotCrumbleSpec::EditableCounter::SetCountAction.handle(ctx).should be_true

    HotCrumbleSpec::EditableCounter.find(counter.id.value).count.value.should eq(5)
  end

  it "preserves errors and model-aware action form options on invalid submission" do
    counter = HotCrumbleSpec::EditableCounter.create(count: 2)
    response = String.build do |io|
      ctx = Crumble::Server::TestRequestContext.new(response_io: io, method: "POST", resource: HotCrumbleSpec::EditableCounter::SetCountAction.uri_path(counter.id.value), body: URI::Params.encode({value: ""}))
      HotCrumbleSpec::EditableCounter::SetCountAction.handle(ctx).should be_true
      ctx.response.status_code.should eq(200)
      ctx.response.flush
    end

    HotCrumbleSpec::EditableCounter.find(counter.id.value).count.value.should eq(2)
    response.should contain(%(<div class="errors">value</div>))
    response.should contain(%(<option value="" selected>Pick a count</option>))
    response.should contain(%(<option value="2">Current 2</option>))
  end

  it "loads Orma models into crumble pages" do
    article = HotCrumbleSpec::Article.create(title: "Upgraded article")
    response = String.build do |io|
      ctx = Crumble::Server::TestRequestContext.new(response_io: io, method: "GET", resource: HotCrumbleSpec::ArticlePage.uri_path(article_id: article.id.value))
      HotCrumbleSpec::ArticlePage.handle(ctx).should be_true
      ctx.response.status_code.should eq(200)
      ctx.response.flush
    end

    response.should contain("Upgraded article")
  end

  it "renders the configured fallback view when a page model is missing" do
    response = String.build do |io|
      ctx = Crumble::Server::TestRequestContext.new(response_io: io, method: "GET", resource: HotCrumbleSpec::ArticlePage.uri_path(article_id: 404))
      HotCrumbleSpec::ArticlePage.handle(ctx).should be_true
      ctx.response.status_code.should eq(404)
      ctx.response.flush
    end

    response.should contain("Article not found")
  end

  it "renders localized pages from the request Accept-Language header" do
    response = String.build do |io|
      ctx = Crumble::Server::TestRequestContext.new(response_io: io, method: "GET", resource: HotCrumbleSpec::LocalizedPage.uri_path, headers: HTTP::Headers{"Accept-Language" => "de"})
      HotCrumbleSpec::LocalizedPage.handle(ctx).should be_true
      ctx.response.flush
    end

    response.should contain("<h1>Hallo</h1>")
  end

  it "translates crumble form labels through crumble-crababel" do
    form = HotCrumbleSpec::LocalizedForm.new(test_handler_context(headers: HTTP::Headers{"Accept-Language" => "de"}), email: "ada@example.com")

    form.to_html.should contain(">E-Mail-Adresse<")
  end

  it "enqueues crumble-jobs work from a crumble-turbo action" do
    HotCrumbleSpec::AuditJob.clear
    Crumble::Jobs.set_queue(Crumble::Jobs::InMemoryQueue.new)

    response = String.build do |io|
      ctx = Crumble::Server::TestRequestContext.new(response_io: io, method: "POST", resource: HotCrumbleSpec::EnqueueJobAction.uri_path)
      HotCrumbleSpec::EnqueueJobAction.handle(ctx).should be_true
      ctx.response.flush
    end

    Crumble::Jobs::Worker.new(poll_interval: 10.milliseconds).run_once(10.milliseconds).should be_true

    # The in-memory worker executes asynchronously, so give it a short deadline to finish.
    deadline = Time.instant + 100.milliseconds
    until HotCrumbleSpec::AuditJob.runs.size == 1 || Time.instant >= deadline
      sleep 1.millisecond
    end

    response.should contain("<turbo-stream")
    HotCrumbleSpec::AuditJob.runs.should eq(["from action|2"])
  end

  it "retries jobs configured with retry_on" do
    HotCrumbleSpec::RetryingAuditJob.clear
    Crumble::Jobs.set_queue(Crumble::Jobs::InMemoryQueue.new)
    HotCrumbleSpec::RetryingAuditJob.enqueue(token: "retry")

    worker = Crumble::Jobs::Worker.new(max_concurrency: 1, poll_interval: 1.millisecond)
    deadline = Time.instant + 2.seconds
    until HotCrumbleSpec::RetryingAuditJob.runs.size == 2 || Time.instant >= deadline
      worker.run_once(20.milliseconds)
      sleep 1.millisecond
    end

    HotCrumbleSpec::RetryingAuditJob.runs.should eq(["retry", "retry"])
    worker.run_once(20.milliseconds).should be_false
  end

  it "registers stimulus controllers in the shared layout assets" do
    controller_name = HotCrumbleSpec::ClipboardController.controller_name
    layout = HotCrumbleSpec::ApplicationLayout.new(ctx: test_handler_context)
    asset_file = AssetFileRegistry.query(Crumble::StimulusControllers.uri_path).not_nil!

    layout.head_children.should contain(Crumble::StimulusControllers)
    Crumble::StimulusControllers.to_js.should contain("Stimulus.register(#{HotCrumbleSpec::ClipboardController.controller_name.to_js_ref}, #{HotCrumbleSpec::ClipboardController.to_js_ref});")
    asset_file.contents.should contain("class HotCrumbleSpec_ClipboardController extends Controller")
    HotCrumbleSpec::ClipboardController.message_value("Copied").attr_name.should eq("data-#{controller_name}-message-value")
    HotCrumbleSpec::ClipboardController.output_target.attr_name.should eq("data-#{controller_name}-target")
    HotCrumbleSpec::ClipboardController.copy_action("click").attr_value.should eq("click->#{controller_name}#copy")
  end
end

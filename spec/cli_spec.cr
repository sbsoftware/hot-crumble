require "./spec_helper"
require "../src/hot_crumble/cli"
require "file_utils"

describe HotCrumble::CLI do
  around_each do |example|
    root = File.join(Dir.tempdir, "hot-crumble-cli-#{Process.pid}-#{Time.utc.to_unix_ms}-#{Random.rand(1_000_000)}")
    FileUtils.mkdir_p(root)

    begin
      Dir.cd(root) do
        File.write("shard.yml", "name: sample_app\nversion: 0.1.0\n")
        example.run
      end
    ensure
      FileUtils.rm_r(root) if Dir.exists?(root)
    end
  end

  it "generates the hot-crumble scaffold and action-aware environment" do
    HotCrumble::CLI.new(["init"], IO::Memory.new, IO::Memory.new).run.should eq(0)

    %w(src src/crumble src/models src/actions src/views src/resources src/styles src/pages).each do |path|
      Dir.exists?(path).should be_true
    end

    %w(.env AGENTS.md watch.sh src/environment.cr src/sample_app.cr src/crumble/session.cr src/crumble/request_context.cr src/models/application_record.cr src/views/application_layout.cr src/pages/application_page.cr src/pages/welcome_page.cr src/resources/application_resource.cr src/styles/application_style.cr).each do |path|
      File.exists?(path).should be_true
    end

    File.read("src/environment.cr").should eq(%(require "hot-crumble"

# Load base application types first so files in nested folders can reference them.
require "./crumble/session"
require "./crumble/request_context"
require "./models/application_record"
require "./views/application_layout"
require "./pages/application_page"
require "./resources/application_resource"
require "./styles/application_style"

require "./crumble/**"
require "./models/**"
require "./actions/**"
require "./views/**"
require "./pages/**"
require "./resources/**"
require "./styles/**"
))
    File.read("src/models/application_record.cr").should eq(%(abstract class ApplicationRecord < Orma::Record
  macro inherited
    id_column id : Int64
  end
end
))
    File.read("src/sample_app.cr").should eq(%(require "./environment"

Crumble::Server.start
))
    File.read("watch.sh").should contain(%(exec "$SCRIPT_DIR/lib/crumble/src/watch.sh" "sample_app" "0"))
  end

  it "keeps non-overwritten files and still applies name and port options" do
    FileUtils.mkdir_p("src/pages")
    File.write("src/pages/welcome_page.cr", "class WelcomePage\nend\n")
    File.write("src/environment.cr", "require \"crumble\"\n")
    File.write("src/custom_app.cr", "puts \"old\"\n")

    HotCrumble::CLI.new(["init", "--name", "custom_app", "--port", "4321"], IO::Memory.new, IO::Memory.new).run.should eq(0)

    File.read("src/pages/welcome_page.cr").should eq("class WelcomePage\nend\n")
    File.read("src/environment.cr").should contain(%(require "hot-crumble"))
    File.read("src/custom_app.cr").should eq(%(require "./environment"

Crumble::Server.start
))
    Dir.exists?("src/actions").should be_true
    File.read("watch.sh").should contain(%(exec "$SCRIPT_DIR/lib/crumble/src/watch.sh" "custom_app" "4321"))
  end
end

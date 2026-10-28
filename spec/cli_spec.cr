require "./spec_helper"
require "file_utils"
require "../src/hot_crumble/cli"

describe HotCrumble::CLI do
  it "delegates base generation before adding hot-crumble files" do
    path = File.tempname("hot-crumble-init")
    Dir.mkdir(path)

    begin
      Dir.cd(path) do
        Dir.mkdir_p("lib")
        File.symlink(Path[__DIR__, "..", "lib", "crumble"].expand, Path["lib", "crumble"])
        HotCrumble::CLI.new(["init", "--name", "test_app"]).run.should eq(0)
        File.exists?("src/test_app.cr").should be_true
        File.exists?("src/actions").should be_true
        File.read("src/models/application_record.cr").should eq(HotCrumble::CLI::APPLICATION_RECORD)
        File.read("config/locales/en.yml").should eq(HotCrumble::CLI::EN_LOCALE_TEMPLATE)
        File.read("Dockerfile").should eq(HotCrumble::CLI::DOCKERFILE_TEMPLATE)
        File.read("Dockerfile").should contain("libsqlite3-dev")
      end
    ensure
      FileUtils.rm_rf(path)
    end
  end

  it "preserves an existing Dockerfile" do
    path = File.tempname("hot-crumble-init")
    Dir.mkdir(path)

    begin
      Dir.cd(path) do
        Dir.mkdir_p("lib")
        File.symlink(Path[__DIR__, "..", "lib", "crumble"].expand, Path["lib", "crumble"])
        File.write("Dockerfile", "custom Dockerfile\n")
        HotCrumble::CLI.new(["init", "--name", "test_app"]).run.should eq(0)
        File.read("Dockerfile").should eq("custom Dockerfile\n")
      end
    ensure
      FileUtils.rm_rf(path)
    end
  end

  it "returns crumble's failure status without generating hot-crumble files" do
    path = File.tempname("hot-crumble-init")
    Dir.mkdir(path)

    begin
      Dir.cd(path) do
        HotCrumble::CLI.new(["init", "--name", "test_app"], IO::Memory.new, IO::Memory.new).run.should_not eq(0)
        File.exists?("config").should be_false
        File.exists?("Dockerfile").should be_false
      end
    ensure
      FileUtils.rm_rf(path)
    end
  end
end

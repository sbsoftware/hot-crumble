require "./spec_helper"
require "file_utils"
require "../src/hot_crumble/cli"

describe HotCrumble::CLI do
  it "generates a Dockerfile for the Docker-aware watcher" do
    path = File.tempname("hot-crumble-init")
    Dir.mkdir(path)

    begin
      Dir.cd(path) do
        HotCrumble::CLI.new(["init", "--name", "test_app"]).run.should eq(0)
        File.read("Dockerfile").should eq(HotCrumble::CLI::DOCKERFILE_TEMPLATE)
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
        File.write("Dockerfile", "custom Dockerfile\n")
        HotCrumble::CLI.new(["init", "--name", "test_app"]).run.should eq(0)
        File.read("Dockerfile").should eq("custom Dockerfile\n")
      end
    ensure
      FileUtils.rm_rf(path)
    end
  end
end

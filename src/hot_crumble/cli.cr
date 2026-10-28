require "option_parser"

module HotCrumble
  class CLI
    enum Command
      Init
    end

    CRUMBLE_CLI             = Path["lib", "crumble", "src", "cli.cr"]
    HOT_CRUMBLE_DIRECTORIES = [Path["config"], Path["config", "locales"], Path["tmp"], Path["tmp", "sessions"], Path["src", "actions"]]
    APPLICATION_RECORD      = {{read_file "#{__DIR__}/cli/templates/application_record.cr"}}
    EN_LOCALE_TEMPLATE      = {{read_file "#{__DIR__}/cli/templates/en.yml"}}

    @command : Command?
    @argv : Array(String)
    @name : String?
    @local_port : String? = "0"
    @verbose = false

    getter parser : OptionParser

    def initialize(argv = ARGV, @stdout : IO = STDOUT, @stderr : IO = STDERR)
      @argv = argv.dup
      @parser = OptionParser.new
      configure_parser
      @parser.parse(@argv)
    end

    def run : Int32
      case @command
      in Command::Init
        init
      in Nil
        log @parser.to_s
        1
      end
    end

    def init : Int32
      args = ["run", CRUMBLE_CLI.to_s, "--", "init"]
      args.concat(["--name", @name.to_s]) if @name
      args.concat(["--port", @local_port.to_s])
      args << "--verbose" if @verbose
      status = Process.run("crystal", args, output: @stdout, error: @stderr)
      return status.exit_code unless status.success?

      HOT_CRUMBLE_DIRECTORIES.each { |path| Dir.mkdir_p(path) }
      {Path["src", "models", "application_record.cr"] => APPLICATION_RECORD, Path["config", "locales", "en.yml"] => EN_LOCALE_TEMPLATE}.each do |path, contents|
        File.write(path, contents) unless File.exists?(path)
      end
      0
    end

    def log(str : String)
      @stdout.puts str
    end

    private def configure_parser
      @parser.banner = "Usage: hot-crumble [command] [options]"
      @parser.on("init", "Initialize new hot-crumble app") do
        @command = Command::Init
        @parser.banner = "Usage: hot-crumble init [options]"
        @parser.on("-n", "--name NAME", "The name of the main executable") { |name| @name = name }
        @parser.on("-p", "--port PORT", "Local port the server started by watch.sh will listen to") { |port| @local_port = port }
        @parser.on("--help", "Print out help") { log @parser.to_s }
      end
      @parser.on("-v", "--verbose", "Comment every step") { @verbose = true }
    end
  end
end

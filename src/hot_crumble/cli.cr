require "option_parser"
require "yaml"

module HotCrumble
  class CLI
    enum Command
      Init
    end

    SRC_FOLDER               = "src"
    CONFIG_FOLDER            = "config"
    LOCALES_FOLDER           = Path.new(CONFIG_FOLDER, "locales")
    CRUMBLE_FOLDER           = Path.new(SRC_FOLDER, "crumble")
    TMP_FOLDER               = "tmp"
    TMP_SESSIONS_FOLDER      = Path.new(TMP_FOLDER, "sessions")
    MODELS_FOLDER            = Path.new(SRC_FOLDER, "models")
    ACTIONS_FOLDER           = Path.new(SRC_FOLDER, "actions")
    VIEWS_FOLDER             = Path.new(SRC_FOLDER, "views")
    RESOURCES_FOLDER         = Path.new(SRC_FOLDER, "resources")
    STYLES_FOLDER            = Path.new(SRC_FOLDER, "styles")
    PAGES_FOLDER             = Path.new(SRC_FOLDER, "pages")
    DOCKERFILE_TEMPLATE      = {{read_file "#{__DIR__}/cli/templates/Dockerfile"}}
    ENV_TEMPLATE             = {{read_file "#{__DIR__}/cli/templates/.env"}}
    AGENTS_TEMPLATE          = {{read_file "#{__DIR__}/cli/templates/AGENTS.md"}}
    APPLICATION_LAYOUT       = {{read_file "#{__DIR__}/cli/templates/application_layout.cr"}}
    APPLICATION_PAGE         = {{read_file "#{__DIR__}/cli/templates/application_page.cr"}}
    APPLICATION_RECORD       = {{read_file "#{__DIR__}/cli/templates/application_record.cr"}}
    APPLICATION_RESOURCE     = {{read_file "#{__DIR__}/cli/templates/application_resource.cr"}}
    APPLICATION_STYLE        = {{read_file "#{__DIR__}/cli/templates/application_style.cr"}}
    EN_LOCALE_TEMPLATE       = {{read_file "#{__DIR__}/cli/templates/en.yml"}}
    ENVIRONMENT_TEMPLATE     = {{read_file "#{__DIR__}/cli/templates/environment.cr"}}
    MAIN_TEMPLATE            = {{read_file "#{__DIR__}/cli/templates/main.cr"}}
    REQUEST_CONTEXT_TEMPLATE = {{read_file "#{__DIR__}/cli/templates/request_context.cr"}}
    SESSION_TEMPLATE         = {{read_file "#{__DIR__}/cli/templates/session.cr"}}
    WATCH_TEMPLATE           = {{read_file "#{__DIR__}/cli/templates/watch.sh"}}
    WELCOME_PAGE             = {{read_file "#{__DIR__}/cli/templates/welcome_page.cr"}}

    @command : Command?
    @argv : Array(String)
    @name : String? = HotCrumble::CLI.parse_shard_name
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
        0
      in Nil
        log @parser.to_s
        1
      end
    end

    def init : Nil
      ensure_dir(SRC_FOLDER)
      ensure_dir(CONFIG_FOLDER)
      ensure_dir(TMP_FOLDER)
      ensure_dir(TMP_SESSIONS_FOLDER)
      ensure_dir(LOCALES_FOLDER)
      ensure_dir(CRUMBLE_FOLDER)
      ensure_dir(MODELS_FOLDER)
      ensure_dir(ACTIONS_FOLDER)
      ensure_dir(VIEWS_FOLDER)
      ensure_dir(RESOURCES_FOLDER)
      ensure_dir(STYLES_FOLDER)
      ensure_dir(PAGES_FOLDER)
      overwrite_file("#{SRC_FOLDER}/environment.cr", ENVIRONMENT_TEMPLATE)
      overwrite_file("#{SRC_FOLDER}/#{@name}.cr", MAIN_TEMPLATE) if @name
      log @parser.to_s unless @name
      ensure_file("#{CRUMBLE_FOLDER}/session.cr", SESSION_TEMPLATE)
      ensure_file("#{CRUMBLE_FOLDER}/request_context.cr", REQUEST_CONTEXT_TEMPLATE)
      ensure_file("#{MODELS_FOLDER}/application_record.cr", APPLICATION_RECORD)
      ensure_file("#{RESOURCES_FOLDER}/application_resource.cr", APPLICATION_RESOURCE)
      ensure_file("#{STYLES_FOLDER}/application_style.cr", APPLICATION_STYLE)
      ensure_file("#{VIEWS_FOLDER}/application_layout.cr", APPLICATION_LAYOUT)
      ensure_file("#{PAGES_FOLDER}/application_page.cr", APPLICATION_PAGE)
      ensure_file("#{PAGES_FOLDER}/welcome_page.cr", WELCOME_PAGE)
      ensure_file("#{LOCALES_FOLDER}/en.yml", EN_LOCALE_TEMPLATE)
      ensure_file(".env", ENV_TEMPLATE)
      ensure_file("Dockerfile", DOCKERFILE_TEMPLATE)
      ensure_file("watch.sh", watch_script_template, 0o755)
      ensure_file("AGENTS.md", AGENTS_TEMPLATE)
    end

    def watch_script_template
      WATCH_TEMPLATE.gsub("__CRUMBLE_NAME__", @name.to_s).gsub("__CRUMBLE_PORT__", @local_port.to_s)
    end

    def log_verbose(str : String)
      @stderr.puts str
    end

    def log(str : String)
      @stdout.puts str
    end

    def ensure_dir(path : String | Path)
      path = path.to_s
      if Dir.exists?(path)
        log_verbose "#{path} already exists" if @verbose
      else
        log_verbose "Creating #{path}" if @verbose
        Dir.mkdir path
      end
    end

    def ensure_file(path : String, default_contents : String, mode : Int32? = nil)
      if File.exists?(path)
        log_verbose "#{path} already exists" if @verbose
      else
        log_verbose "Creating #{path}" if @verbose
        File.write path, default_contents
        File.chmod(path, mode) if mode
      end
    end

    def overwrite_file(path : String, contents : String)
      log_verbose "Overwriting #{path}" if @verbose
      File.write path, contents
    end

    def self.parse_shard_name
      return unless File.exists?("shard.yml")

      File.open("shard.yml") do |file|
        YAML.parse(file)
      end["name"].to_s
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

module FaaStRuby
  module Command
    module Function
      class DeployTo < FunctionBaseCommand
        def initialize(args)
          @args = args
          @missing_args = []
          FaaStRuby::CLI.error(@missing_args, color: nil) if missing_args.any?
          @workspace_name = @args.shift
          load_yaml
          @yaml_config['before_build'] ||= []
          @function_name = @yaml_config['name']
          @abort_when_tests_fail = @yaml_config['abort_deploy_when_tests_fail']
          load_credentials(exit_on_error: false)
        end

        def ruby_runtime?
          @yaml_config['runtime'].nil? || @yaml_config['runtime'].match(/^ruby/)
        end

        def crystal_runtime?
          @yaml_config['runtime'].match(/^crystal/)
        end

        def run
          create_or_use_workspace
          if ruby_runtime?
            FaaStRuby::CLI.error('Please fix the problems above and try again') unless bundle_install
          end
          if crystal_runtime?
            FaaStRuby::CLI.error('Please fix the problems above and try again') unless shards_install
          end
          tests_passed = run_tests
          FaaStRuby::CLI.error("Deploy aborted because tests failed and you have 'abort_deploy_when_tests_fail: true' in 'faastruby.yml'") unless tests_passed || !@abort_when_tests_fail
          puts "[#{@function_name}] Warning: Ignoring failed tests because you have 'abort_deploy_when_tests_fail: false' in 'faastruby.yml'".yellow if !tests_passed && !@abort_when_tests_fail
          package_file_name = build_package
          spinner = spin("[#{@function_name}] Deploying function '#{@function_name}' to workspace '#{@workspace_name}'...")
          workspace = FaaStRuby::Workspace.new(name: @workspace_name).deploy(package_file_name)
          if workspace.errors.any?
            spinner.stop('Failed :(')
            FileUtils.rm('.package.zip')
            FaaStRuby::CLI.error(workspace.errors)
          end
          spinner.stop('Done!')
          FileUtils.rm('.package.zip')
          puts "* [#{@function_name}] Endpoint: #{FaaStRuby.workspace_host_for(@workspace_name)}/#{@function_name}".green
          exit 0
        end

        def self.help
          "deploy-to".light_cyan + " WORKSPACE_NAME"
        end

        def usage
          "Usage: faastruby #{self.class.help}"
        end

        private

        def load_credentials(exit_on_error:)
          @has_credentials = FaaStRuby::Credentials.load_for(@workspace_name, exit_on_error: exit_on_error)
        end

        def create_or_use_workspace
          unless @has_credentials
            puts "[#{@function_name}] Attemping to create workspace '#{@workspace_name}'"
            cmd = FaaStRuby::Command::Workspace::Create.new([@workspace_name])
            cmd.run(create_directory: false, exit_on_error: true)
            load_credentials(exit_on_error: true)
            # Give a little bit of time after creating the workspace
            # for consistency. This is temporary until the API gets patched.
            spinner = spin("Waiting for the new workspace to be ready...")
            sleep 2
            spinner.stop("Done!")
          end
        end

        def shards_install
          return true unless File.file?('shard.yml')
          puts "[#{@function_name}] [build] Verifying dependencies"
          system('shards check') || system('shards install')
        end

        def bundle_install
          return true unless File.file?('Gemfile')
          puts "[#{@function_name}] [build] Verifying dependencies"
          system('bundle check') || system('bundle install')
        end

        def missing_args
          if @args.empty?
            @missing_args << "Missing argument: WORKSPACE_NAME".red
            @missing_args << usage
          end
          FaaStRuby::CLI.error(["'#{@args.first}' is not a valid workspace name.".red, usage], color: nil) if @args.first =~ /^-.*/
          @missing_args
        end

        def run_tests
          FaaStRuby::Command::Function::Test.new(true).run(do_not_exit: true)
        end

        def build_package
          source = '.'
          output_file = ".package.zip"
          if @yaml_config['before_build'].any?
            spinner = spin("[#{@function_name}] Running 'before_build' tasks...")
            @yaml_config['before_build']&.each do |command|
              puts `#{command}`
            end
            spinner.stop(' Done!')
          end
          FaaStRuby::Command::Function::Build.build(source, output_file, @function_name, true)
          output_file
        end
      end
    end
  end
end

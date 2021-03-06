require 'faastruby/api'

module FaaStRuby
  class Workspace < BaseObject

    ##### Class methods
    def self.create(name:, email: nil, provider: nil)
      api = API.new
      workspace = Workspace.new(name: name, email: email, errors: [], provider: provider)
      response = api.create_workspace(workspace_name: name, email: email, provider: provider)
      workspace.status_code = response.code
      if response.errors.any?
        workspace.errors += response.errors
        return workspace
      end
      case response.code
      when 422
        workspace.errors += ['(422) Unprocessable Entity', response.body]
      when 200, 201
        workspace.credentials = response.body['credentials']
      else
        workspace.errors << "(#{response.code}) Error"
      end
      return workspace
    end
    ###################

    ##### Instance methods
    attr_accessor :name, :errors, :functions, :email, :object, :credentials, :updated_at, :created_at, :status_code, :provider

    def destroy
      response = @api.destroy_workspace(@name)
      @status_code = response.code
      @errors += response.errors if response.errors.any?
    end

    def deploy(package_file_name)
      response = @api.deploy(workspace_name: @name, package: package_file_name)
      @status_code = response.code
      @errors += response.errors if response.errors.any?
      self
    end

    def refresh_credentials
      response = @api.refresh_credentials(@name)
      @status_code = response.code
      @credentials = response.body[@name] unless response.body.nil?
      @errors += response.errors if response.errors.any?
      self
    end

    def fetch
      response = @api.get_workspace_info(@name)
      @status_code = response.code
      if response.errors.any?
        @errors += response.errors
      else
        parse_attributes(response.body)
      end
      self
    end

    def parse_attributes(attributes)
      @functions = attributes['functions']
      @email = attributes['email']
      @object = attributes['object']
      @updated_at = attributes['updated_at']
      @created_at = attributes['created_at']
      @provider = attributes['provider']
    end
  end
end
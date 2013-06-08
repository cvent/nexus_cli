module NexusCli
  class ArtifactResource

    FILE_NAME_KEYS = [ :a, :v, :e ].freeze

    include Celluloid

    def initialize(connection_registry)
      @connection_registry = connection_registry
    end

    # @return [NexusCli::ArtifactObject]
    def find(artifact_id)
      artifact_id_hash = artifact_id.to_artifact_hash
      artifact_id_hash[:r] = connection.default_repository

      ArtifactObject.new(request(:get, "artifact/maven/resolve", artifact_id_hash))
    end

    def download(artifact_id, location = ".")
      artifact_id_hash = artifact_id.to_artifact_hash
      artifact_id_hash[:r] = connection.default_repository

      if latest?(artifact_id_hash[:v])
        p :before_artifact_id_hash, artifact_id_hash
        artifact_id_hash[:v] = find(artifact_id).version
      end

      p :after_artifact_id_hash, artifact_id_hash
      redirect_url = connection.get("artifact/maven/redirect", artifact_id_hash).headers["location"]
      recomposed_artifact_id = artifact_id_hash.values.join(':')
      download_path = File.join(File.expand_path(location), file_name_for(recomposed_artifact_id))

      connection.stream(redirect_url, download_path)
    end

    def upload(artifact_id, file)
      repository_path = repository_path_for(artifact_id)
      file_name = file_name_for(artifact_id)

      success = request(:put, "content/repositories/#{connection.default_repository}/#{repository_path}/#{file_name}", File.read(File.expand_path(file)))
      return success
      if success
        # pom_name = pom_name_for(artifact_id_hash)
        # fake_pom = create_fake_pom(artifact_id.to_artifact_id_hash)
        # 
        # request(:put, "content/repositories/#{connection.default_repository}/#{repository_path}/#{pom_name}", File.open(fake_pom))
        # 
        # delete_metadata(artifact_id)
      end
    end

    # Converts an artifact identifier string into a file
    # name.
    #
    # @param  artifact_id [String]
    # 
    # @example file_name_for("com:my-test:1.0.1:tgz") => "my-test-1.0.1.tgz"
    # 
    # @return [String]
    def file_name_for(artifact_id)
      parts = artifact_id.to_artifact_hash.slice(*FILE_NAME_KEYS)
      "#{parts[:a]}-#{parts[:v]}.#{parts[:e]}"
    end

    def repository_path_for(artifact_id)
      artifact_id_hash = artifact_id.to_artifact_hash
      "#{artifact_id_hash[:g].gsub('.', '/')}/#{artifact_id_hash[:a]}/#{artifact_id_hash[:v]}"
    end

    def latest?(version)
      version.casecmp("latest") == 0
    end

    # @return [NexusCli::Connection]
    def connection
      @connection_registry[:connection_pool]
    end

    private

      def create_fake_pom(artifact_id_hash)
        Tempfile.open(pom_name_for(artifact_id_hash)) do |file|
          template_path = File.join(NexusCli.root, "data", "pom.xml.erb")
          file.puts ERB.new(File.read(template_path)).result(binding)
          file
        end
      end

      def pom_name_for(artifact_id_hash)
        "#{artifact_id_hash[:a]}-#{artifact_id_hash[:v]}.pom"
      end

      # @param [Symbol] method
      def request(method, *args)
        raw_request(method, *args).body
      end

      # @param [Symbol] method
      def raw_request(method, *args)
        unless Connection::METHODS.include?(method)
          #raise Errors::HTTPUnknownMethod, "unknown http method: #{method}"
        end

        connection.send(method, *args)
      rescue => ex
        abort(ex)
      end
  end
end

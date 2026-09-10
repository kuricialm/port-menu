import Foundation

struct LocalCanRoutes {
    struct LoadResult: Sendable {
        var routes: [UInt16: [URL]]
        var warnings: [String]
    }

    // Parse saved YAML with macOS's bundled Ruby/Psych. Never execute YAML objects
    // or modify projects. Match only enabled local endpoints and loopback origins.
    static func load(projectsDirectory: URL? = nil) async throws -> LoadResult {
        let script = #"""
        require 'yaml'
        require 'json'
        require 'uri'
        result = {}
        warnings = []
        directory = ARGV.fetch(0)
        Dir.glob(File.join(directory, '*.{yml,yaml}')).sort.each do |file|
          label = File.basename(file)
          begin
            project = YAML.safe_load(File.read(file), permitted_classes: [], aliases: false)
            raise 'expected a project mapping' unless project.is_a?(Hash)
            next if project['enabled'] == false
            services = project.fetch('services', {})
            raise 'expected a services mapping' unless services.is_a?(Hash)
          rescue StandardError => error
            warnings << "#{label}: could not read project (#{error.class})."
            next
          end
          services.each do |name, service|
            begin
              raise 'expected a service mapping' unless service.is_a?(Hash)
              next if service['enabled'] == false
              target = URI.parse(service['target'].to_s)
              next unless ['http', 'https'].include?(target.scheme) && ['localhost', '127.0.0.1', '[::1]', '::1'].include?(target.host)
              port = target.port
              raise 'invalid target port' unless port && port.between?(1, 65535)
              endpoints = service.fetch('endpoints', [])
              raise 'expected an endpoints list' unless endpoints.is_a?(Array)
            rescue StandardError => error
              warnings << "#{label}, service #{name}: could not read route (#{error.class})."
              next
            end
            endpoints.each_with_index do |endpoint, index|
              begin
                raise 'expected an endpoint mapping' unless endpoint.is_a?(Hash)
                next unless endpoint['enabled'] == true
                scheme = endpoint['scheme']
                next unless ['http', 'https'].include?(scheme)
                url = URI.parse("#{scheme}://#{endpoint['url']}")
                next unless url.host && url.host.end_with?('.local') && !url.userinfo
                (result[port.to_s] ||= []) << url.to_s
              rescue StandardError => error
                warnings << "#{label}, service #{name}, endpoint #{index + 1}: could not read URL (#{error.class})."
              end
            end
          end
        end
        puts JSON.generate({'routes' => result, 'warnings' => warnings})
        """#
        let directory = projectsDirectory ?? FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".localcan/projects", directoryHint: .isDirectory)
        let output = try await LivePortScanner().runShell("/usr/bin/ruby", args: ["-e", script, directory.path], timeout: 5)
        let payload = try JSONDecoder().decode(RoutePayload.self, from: Data(output.utf8))
        return LoadResult(routes: decodeRoutes(payload.routes), warnings: payload.warnings)
    }

    static func decode(_ data: Data) throws -> [UInt16: [URL]] {
        let raw = try JSONDecoder().decode([String: [String]].self, from: data)
        return decodeRoutes(raw)
    }

    private static func decodeRoutes(_ raw: [String: [String]]) -> [UInt16: [URL]] {
        var result: [UInt16: [URL]] = [:]
        for (key, values) in raw {
            guard let port = UInt16(key) else { continue }
            result[port] = Array(Set(values.compactMap(URL.init(string:)))).sorted { $0.absoluteString < $1.absoluteString }
        }
        return result
    }

    private struct RoutePayload: Decodable {
        var routes: [String: [String]]
        var warnings: [String]
    }
}

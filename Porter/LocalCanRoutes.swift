import Foundation

struct LocalCanRoutes {
    // Parse saved YAML with macOS's bundled Ruby/Psych. Never execute YAML objects
    // or modify projects. Match only enabled local endpoints and loopback origins.
    static func load() async throws -> [UInt16: [URL]] {
        let script = #"""
        require 'yaml'
        require 'json'
        require 'uri'
        result = {}
        Dir.glob(File.join(Dir.home, '.localcan/projects/*.{yml,yaml}')).sort.each do |file|
          project = YAML.safe_load(File.read(file), permitted_classes: [], aliases: false)
          next unless project.is_a?(Hash)
          next if project['enabled'] == false
          (project['services'] || {}).each_value do |service|
            next unless service.is_a?(Hash) && service['enabled'] != false
            target = URI.parse(service['target'].to_s)
            next unless ['http', 'https'].include?(target.scheme) && ['localhost', '127.0.0.1', '[::1]', '::1'].include?(target.host)
            (service['endpoints'] || []).each do |endpoint|
              next unless endpoint['enabled'] == true
              scheme = endpoint['scheme']
              next unless ['http', 'https'].include?(scheme)
              url = URI.parse("#{scheme}://#{endpoint['url']}")
              next unless url.host && url.host.end_with?('.local') && !url.userinfo
              (result[target.port.to_s] ||= []) << url.to_s
            end
          end
        end
        puts JSON.generate(result)
        """#
        let output = try await LivePortScanner().runShell("/usr/bin/ruby", args: ["-e", script], timeout: 5)
        return try decode(Data(output.utf8))
    }

    static func decode(_ data: Data) throws -> [UInt16: [URL]] {
        let raw = try JSONDecoder().decode([String: [String]].self, from: data)
        var result: [UInt16: [URL]] = [:]
        for (key, values) in raw {
            guard let port = UInt16(key) else { continue }
            result[port] = Array(Set(values.compactMap(URL.init(string:)))).sorted { $0.absoluteString < $1.absoluteString }
        }
        return result
    }
}

import Foundation
import Testing

struct UpdateConfigurationTests {
    @Test func builtAppContainsForkUpdateIdentity() throws {
        let info = try #require(Bundle.main.infoDictionary)
        #expect(info["SUFeedURL"] as? String == "https://github.com/kuricialm/port-menu/releases/latest/download/appcast.xml")
        #expect(info["SUPublicEDKey"] as? String == "0X1eQatxgbA81qc/hSYxzuVC/KfbQggxyF9uJthrBqw=")
        for key in ["SUEnableAutomaticChecks", "SUAutomaticallyUpdate", "SURequireSignedFeed", "SUVerifyUpdateBeforeExtraction"] {
            #expect(info[key] as? Bool == true)
        }
        #expect(info["SUScheduledCheckInterval"] as? Int == 3600)
    }
}

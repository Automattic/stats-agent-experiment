import AuthenticationServices
import Foundation
import Observation
import SwiftUI
import WordPressAPI
import WordPressAPIInternal

/// A site on the WordPress.com account, as the site list shows it.
struct Site: Codable, Hashable, Identifiable {
    let id: WpComSiteId
    let name: String
    let url: String
    /// The time zone the site's stats are reported in, or nil when its options don't say.
    let timeZone: TimeZone?

    /// The site's name, or its URL when it has none.
    var title: String {
        name.isEmpty ? url : name
    }

    /// The time zone in a site's options, read as the WordPress iOS app reads it: the `timezone` name, otherwise the
    /// `gmt_offset` in hours. WordPress.com gives the options only to people who can edit the site's posts.
    static func timeZone(from options: [String: JsonValue]) -> TimeZone? {
        if case .string(let name) = options["timezone"], !name.isEmpty, let timeZone = TimeZone(identifier: name) {
            return timeZone
        }
        let hours: Double? =
            switch options["gmt_offset"] {
            case .int(let hours): Double(hours)
            case .float(let hours): hours
            case .string(let hours): Double(hours)
            default: nil
            }
        return hours.flatMap { TimeZone(secondsFromGMT: Int($0 * 3600)) }
    }
}

/// The WordPress.com login and the site questions are about. Release builds, such as `make app`'s, keep the token in
/// the keychain, so it lasts from one launch to the next. Debug builds, such as `make run`'s, keep it only while they
/// run and ask to log in at each launch, since the keychain asks again for the token whenever a build's code changes;
/// they leave the keychain alone. The site is kept in the app's defaults. Logging out forgets both.
@MainActor @Observable
final class Account {
    private(set) var token: String?
    private(set) var site: Site?
    /// Whether the site list shows in place of the questions while another site is picked.
    var isChoosingSite = false

    /// The sites `--previews` gives in place of the account's.
    private var previewSites: [Site]?

    private static let siteKey = "site"

    /// Whether the token is kept in the keychain: in release builds only.
    private static var keepsToken: Bool {
        #if DEBUG
        false
        #else
        true
        #endif
    }

    init() {
        token = Self.keepsToken ? Keychain.token() : nil
        site = UserDefaults.standard.data(forKey: Self.siteKey)
            .flatMap { try? JSONDecoder().decode(Site.self, from: $0) }
    }

    /// An account as `--previews` draws it, without the keychain, the app's defaults or WordPress.com: `sites` is
    /// what `sites()` returns.
    init(previewToken token: String?, site: Site?, sites: [Site] = []) {
        self.token = token
        self.site = site
        previewSites = sites
    }

    /// The selected site's stats, or nil before logging in and picking a site.
    var stats: SiteStats? {
        guard let token, let site else {
            return nil
        }
        return SiteStats(token: token, siteID: site.id)
    }

    func logIn(in session: WebAuthenticationSession) async throws {
        let token = try await OAuthClient.compiledIn().token(in: session)
        if Self.keepsToken {
            try Keychain.save(token)
        }
        self.token = token
    }

    /// The account's sites, sorted by name.
    func sites() async throws -> [Site] {
        if let previewSites {
            return previewSites
        }
        guard let token else {
            return []
        }
        let response = try await WPComApiClient(authentication: .bearer(token: token)).sites
            .get(params: SitesListParams())
        return response.data.sites
            .map { Site(id: $0.id, name: $0.name, url: $0.url, timeZone: Site.timeZone(from: $0.options)) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    func choose(_ site: Site) {
        self.site = site
        UserDefaults.standard.set(try? JSONEncoder().encode(site), forKey: Self.siteKey)
        isChoosingSite = false
    }

    func logOut() {
        if Self.keepsToken {
            Keychain.deleteToken()
        }
        UserDefaults.standard.removeObject(forKey: Self.siteKey)
        token = nil
        site = nil
        isChoosingSite = false
    }
}

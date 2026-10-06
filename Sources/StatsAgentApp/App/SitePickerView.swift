import SwiftUI

/// The account's sites, filtered by name or URL, to pick the one questions are about, in a column in the middle of the
/// window. Logging out is here too, for using another account.
struct SitePickerView: View {
    let account: Account
    /// Asks whether to log out.
    let logOut: () -> Void
    @State private var sites: [Site]?
    @State private var error: String?
    @State private var filter = ""

    var body: some View {
        // The whole page scrolls, so the list's box fits its sites and a long list still scrolls.
        ScrollView {
            page
        }
        .task {
            do {
                sites = try await account.sites()
            } catch {
                self.error = Answer.message(for: error)
            }
        }
    }

    private var page: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Choose a site")
                    .font(.largeTitle.weight(.semibold))
                Spacer()
                if account.site != nil {
                    Button("Cancel") { account.isChoosingSite = false }
                }
                Button("Log Out…", action: logOut)
            }
            TextField("Filter by name or URL", text: $filter)
                .textFieldStyle(.plain)
                .focusEffectDisabled()
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .boxStyle(Capsule())
            if let sites {
                list(sites.filter(matches))
            } else if let error {
                Text(error)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Loading your sites…")
                    Text("This can take a minute on accounts with many sites.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
            }
        }
        .frame(maxWidth: 620)
        .padding(32)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private func list(_ sites: [Site]) -> some View {
        if sites.isEmpty {
            Text("No site's name or URL has “\(filter)” in it.")
                .foregroundStyle(.secondary)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(sites) { site in
                    row(site)
                    if site.id != sites.last?.id {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
            .boxStyle(RoundedRectangle(cornerRadius: 14))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func row(_ site: Site) -> some View {
        Button {
            account.choose(site)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(site.title)
                        .font(.headline)
                    Text(site.url)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if site.id == account.site?.id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func matches(_ site: Site) -> Bool {
        filter.isEmpty
            || site.name.localizedCaseInsensitiveContains(filter)
            || site.url.localizedCaseInsensitiveContains(filter)
    }
}

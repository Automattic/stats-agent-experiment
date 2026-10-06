import SwiftUI

/// The account's sites, filtered by name or URL, to pick the one questions are about. Logging out is here too, for
/// using another account.
struct SitePickerView: View {
    let account: Account
    @State private var sites: [Site]?
    @State private var error: String?
    @State private var filter = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Choose a Site")
                    .font(.title2)
                Spacer()
                if account.site != nil {
                    Button("Cancel") { account.isChoosingSite = false }
                }
                Button("Log Out", action: account.logOut)
            }
            TextField("Filter by name or URL", text: $filter)
                .textFieldStyle(.roundedBorder)
            if let sites {
                List(sites.filter(matches)) { site in
                    Button {
                        account.choose(site)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(site.title)
                            Text(site.url)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } else if let error {
                Text(error)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
                Spacer()
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Loading your sites…")
                    Text("This can take a minute on accounts with many sites.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
        .task {
            do {
                sites = try await account.sites()
            } catch {
                self.error = Answer.message(for: error)
            }
        }
    }

    private func matches(_ site: Site) -> Bool {
        filter.isEmpty
            || site.name.localizedCaseInsensitiveContains(filter)
            || site.url.localizedCaseInsensitiveContains(filter)
    }
}

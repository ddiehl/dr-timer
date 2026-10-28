import SwiftUI

/// Credits, contact and the App Store links. Presented from the Plan tab so
/// that nothing extra sits in front of the pilot during a run.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private static let appStoreID = "6827411822"
    private static let appStoreURL =
        URL(string: "https://apps.apple.com/app/id\(appStoreID)")!
    private static let reviewURL =
        URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")!
    private static let websiteURL = URL(string: "https://spartatechnology.com")!
    private static let githubURL = URL(string: "https://github.com/ddiehl")!

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pilot Timer").font(.title2).bold()
                    Text("Dead-reckoning leg timing for VFR navigation.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(Self.versionLine)
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Author") {
                LabeledContent("Built by", value: "Daniel Diehl")
                Link(destination: Self.websiteURL) {
                    Label("spartatechnology.com", systemImage: "globe")
                }
                Link(destination: Self.githubURL) {
                    Label("github.com/ddiehl", systemImage: "curlybraces")
                }
            }

            Section {
                Link(destination: Self.feedbackURL) {
                    Label("Send feedback", systemImage: "envelope")
                }
                Link(destination: Self.reviewURL) {
                    Label("Rate on the App Store", systemImage: "star")
                }
                ShareLink(item: Self.appStoreURL) {
                    Label("Share with a pilot", systemImage: "square.and.arrow.up")
                }
            } header: {
                Text("Feedback")
            } footer: {
                Text("Bug reports and requests are welcome. The version is filled in for you.")
            }

            Section {
                Text("Pilot Timer is a timing aid for dead-reckoning practice. "
                     + "It is not a navigation system and is not certified for "
                     + "flight. Always fly with your planned charts, a watch and "
                     + "the aircraft's own instruments.")
                .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private static var versionLine: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Version \(short) (\(build))"
    }

    /// The subject carries the version so an emailed report names the build it
    /// came from without the pilot having to look it up.
    static var feedbackURL: URL {
        var components = URLComponents(string: "mailto:daniel@spartatechnology.com")!
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Pilot Timer - \(versionLine)")
        ]
        return components.url!
    }
}

import SwiftUI

/// iPhone Settings Center.
///
/// Sections:
///  • SERVERS — list, add, edit, remove daemon endpoints (existing CRUD).
///  • VOICE INPUT — pick between Native Dictation (default), Whisper-via-
///    daemon, or Off. Picker explains the trade-off inline.
///  • DISPLAY — terminal font size (8-12 pt), haptics on/off.
///  • INTERACTION — toggle crown-driven tab switching and history scroll.
///  • CONNECTION — auto-connect to first endpoint on launch.
///  • ABOUT — version + diagnostics.
struct SettingsView: View {
    @EnvironmentObject var store: EndpointStore
    @EnvironmentObject var prefs: Preferences

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    EndpointListView()
                        .navigationTitle("Servers")
                } label: {
                    HStack {
                        Image(systemName: "server.rack")
                            .foregroundStyle(Theme.accent)
                        Text("Servers")
                        Spacer()
                        Text("\(store.endpoints.count)")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: { Text("Endpoints") }
              footer: { Text("These are pushed to your Apple Watch automatically via WatchConnectivity.") }

            Section("Voice Input") {
                Picker("Mode", selection: $prefs.voiceInputMode) {
                    ForEach(Preferences.VoiceInputMode.allCases) { m in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.label)
                            Text(m.subtitle)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }.tag(m.rawValue)
                    }
                }
                .pickerStyle(.inline)

                if prefs.voice == .whisperViaDaemon {
                    Label {
                        Text("Set OPENAI_API_KEY on the daemon, or write the key to ~/.config/watchcli/openai-key (mode 0600).")
                            .font(.caption)
                    } icon: {
                        Image(systemName: "info.circle").foregroundStyle(.yellow)
                    }
                }
            }

            Section("Display") {
                Stepper(value: $prefs.themeFontSize, in: 8...12) {
                    HStack {
                        Text("Terminal font")
                        Spacer()
                        Text("\(prefs.themeFontSize) pt").foregroundStyle(.secondary)
                    }
                }
                Toggle("Haptics on connect / exit", isOn: $prefs.hapticsEnabled)
            }

            Section {
                Toggle("Crown switches tabs", isOn: $prefs.crownTabSwitch)
                Toggle("Crown scrolls output", isOn: $prefs.scrollWithCrown)
            } header: { Text("Crown / Interaction") }
              footer: { Text("When you're not in the slash-command picker, the Digital Crown switches tabs (when enabled) or scrolls terminal output history.") }

            Section("Connection") {
                Toggle("Auto-connect on launch", isOn: $prefs.autoConnect)
            }

            Section("About") {
                LabeledContent("Version", value: appVersion)
                LabeledContent("Build",   value: appBuild)
                Link(destination: URL(string: "https://github.com/xiaobao520123/WatchCLI")!) {
                    Label("Open repository", systemImage: "arrow.up.right.square")
                }
            }
        }
    }

    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.1.0"
    }
    private var appBuild: String {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "1"
    }
}
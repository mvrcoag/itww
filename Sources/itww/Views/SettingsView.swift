import SwiftUI

public struct SettingsView: View {
    @Bindable var controller: AppController

    public init(controller: AppController) {
        self.controller = controller
    }

    public var body: some View {
        Form {
            Section("Shortcut & Workflow") {
                LabeledContent("Global Hotkey") {
                    ShortcutRecorderView(currentShortcut: controller.settings.shortcut) { updated in
                        controller.updateShortcut(updated)
                    }
                }

                Picker("Default Mode", selection: $controller.settings.defaultMode) {
                    ForEach(RewriteMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                Toggle("Show inline word diff by default", isOn: $controller.settings.showDiff)
            }

            Section("Siri / Apple Intelligence") {
                Picker("Model", selection: $controller.settings.modelBackend) {
                    ForEach(ModelBackend.allCases) { backend in
                        Text(backend.title).tag(backend)
                    }
                }
                .onChange(of: controller.settings.modelBackend) { _, _ in
                    controller.refreshSystemStatus()
                }

                Text(controller.settings.modelBackend.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LabeledContent("Status") {
                    switch controller.modelReadiness {
                    case .ready(let detail):
                        Label(detail, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    case .unavailable(let title, _):
                        Label(title, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
                }

                LabeledContent("Creativity (\(String(format: "%.1f", controller.settings.temperature)))") {
                    Slider(value: $controller.settings.temperature, in: 0.0...0.8, step: 0.1)
                        .frame(width: 180)
                }
            }

            Section {
                TextEditor(text: $controller.settings.customStyleRules)
                    .font(.system(size: 12.5))
                    .frame(minHeight: 68, maxHeight: 96)
                    .overlay(alignment: .topLeading) {
                        if controller.settings.customStyleRules.isEmpty {
                            Text("e.g. Never use em dashes. Keep variable names untouched. Prefer direct active voice.")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                                .padding(.top, 6)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
            } header: {
                Text("Always-On Instructions Prompt")
            } footer: {
                Text("Applied to every rewrite alongside your selected mode and any one-off instruction in the HUD.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Permissions & Setup") {
                LabeledContent("Accessibility") {
                    HStack(spacing: 8) {
                        if controller.isAccessibilityTrusted {
                            Label("Granted", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        } else {
                            Label("Not Granted", systemImage: "xmark.circle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                            Button("Grant Access") {
                                controller.promptAccessibility()
                            }
                            .controlSize(.small)
                        }
                        Button("Refresh") {
                            controller.refreshSystemStatus()
                        }
                        .controlSize(.small)
                    }
                }

                LabeledContent("Onboarding") {
                    Button("Open Welcome Guide") {
                        controller.openWelcomeWindow()
                    }
                    .controlSize(.small)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 520)
        .onAppear {
            controller.refreshSystemStatus()
        }
    }
}

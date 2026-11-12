import AppKit
import SwiftUI

public struct WelcomeView: View {
    @Bindable var controller: AppController
    @State private var glowPhase = false

    private let purpleAccent = Color(red: 0.66, green: 0.41, blue: 0.92)
    private let cyanAccent = Color(red: 0.23, green: 0.78, blue: 0.86)

    public init(controller: AppController) {
        self.controller = controller
    }

    public var body: some View {
        ZStack {
            // Deep obsidian canvas + oil aura matching mvrcoag.com
            Color(red: 0.024, green: 0.024, blue: 0.028)
                .ignoresSafeArea()

            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            purpleAccent.opacity(0.26),
                            cyanAccent.opacity(0.18),
                            Color(red: 0.92, green: 0.35, blue: 0.62).opacity(0.18),
                            purpleAccent.opacity(0.26)
                        ],
                        center: .center
                    )
                )
                .frame(width: 420, height: 420)
                .blur(radius: 85)
                .offset(x: glowPhase ? 70 : -70, y: glowPhase ? -90 : -130)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                // Draggable top chrome
                ZStack {
                    WindowDragHandle()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    HStack {
                        HStack(spacing: 8) {
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [purpleAccent, cyanAccent],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 22, height: 1.5)

                            Text("MACOS WRITING UTILITY")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(2.2)
                                .foregroundStyle(Color.white.opacity(0.55))
                        }
                        .allowsHitTesting(false)

                        Spacer()

                        Button {
                            controller.completeOnboarding()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.55))
                                .frame(width: 26, height: 26)
                                .background(Color.white.opacity(0.06), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Close")
                    }
                    .padding(.horizontal, 32)
                }
                .frame(height: 54)

                // Hero Typography
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("Meet ")
                            .font(.system(size: 46, weight: .semibold))
                            .tracking(-2.0)
                            .foregroundStyle(Color(white: 0.95))

                        Text("itww")
                            .font(.custom("Georgia-Italic", size: 48))
                            .foregroundStyle(.white)

                        Text(".")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(purpleAccent)
                    }

                    Text("Select text anywhere on your Mac, hit your shortcut, and let Apple Intelligence fix grammar, sharpen clarity, or apply custom instructions right in place.")
                        .font(.system(size: 14))
                        .lineSpacing(3)
                        .foregroundStyle(Color.white.opacity(0.66))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)

                // Setup Checklist Cards
                VStack(spacing: 12) {
                    accessibilityStepCard
                    appleIntelligenceStepCard
                    shortcutStepCard
                }
                .padding(.horizontal, 32)

                Spacer(minLength: 20)

                // Bottom Action Bar
                HStack(spacing: 12) {
                    if !controller.isAccessibilityTrusted {
                        Label("Grant Accessibility above so global text capture works", systemImage: "info.circle")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Color.white.opacity(0.55))
                    } else {
                        Label("Everything is ready. Try selecting text and pressing \(controller.settings.shortcut.displayString)", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Color(red: 0.56, green: 0.90, blue: 0.64))
                    }

                    Spacer()

                    Button {
                        controller.completeOnboarding()
                    } label: {
                        HStack(spacing: 6) {
                            Text(controller.isAccessibilityTrusted ? "Start Using itww" : "Continue Anyway")
                                .font(.system(size: 13, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(Color.white, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 22)
                .background(Color.white.opacity(0.025))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)
                }
            }
        }
        .preferredColorScheme(.dark)
        .frame(width: 600, height: 550)
        .onAppear {
            controller.refreshSystemStatus()
            controller.startOnboardingPermissionPolling()
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                glowPhase = true
            }
        }
    }

    // MARK: - Step 01: Accessibility

    private var accessibilityStepCard: some View {
        stepContainer(
            number: "01",
            title: "Accessibility Permission",
            subtitle: "Required so itww can read highlighted text in any app and paste the improved text back.",
            isComplete: controller.isAccessibilityTrusted
        ) {
            if controller.isAccessibilityTrusted {
                statusPill(text: "Granted", color: Color(red: 0.45, green: 0.88, blue: 0.58))
            } else {
                Button {
                    controller.promptAccessibility()
                } label: {
                    Text("Grant Access")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(purpleAccent, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Step 02: Apple Intelligence

    private var appleIntelligenceStepCard: some View {
        let isReady = controller.modelReadiness.isReady
        let subtitleText: String = {
            switch controller.modelReadiness {
            case .ready(let detail):
                return "\(detail). Runs privately on Apple Silicon."
            case .unavailable(let title, let guidance):
                return "\(title) — \(guidance)"
            }
        }()

        return stepContainer(
            number: "02",
            title: "Siri & Apple Intelligence",
            subtitle: subtitleText,
            isComplete: isReady
        ) {
            if isReady {
                statusPill(text: "Ready", color: Color(red: 0.45, green: 0.88, blue: 0.58))
            } else {
                HStack(spacing: 6) {
                    Button {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.Siri-Settings.extension") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Text("Open Settings")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.10), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        controller.refreshSystemStatus()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.75))
                            .frame(width: 26, height: 26)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Re-check model availability")
                }
            }
        }
    }

    // MARK: - Step 03: Global Shortcut

    private var shortcutStepCard: some View {
        stepContainer(
            number: "03",
            title: "Your Global Keybinding",
            subtitle: "Click the badge to record your preferred shortcut. Press it whenever text is selected.",
            isComplete: true
        ) {
            ShortcutRecorderView(currentShortcut: controller.settings.shortcut) { updated in
                controller.updateShortcut(updated)
            }
        }
    }

    // MARK: - Reusable Row

    private func stepContainer<Accessory: View>(
        number: String,
        title: String,
        subtitle: String,
        isComplete: Bool,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Text(number)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(isComplete ? purpleAccent : Color.white.opacity(0.45))
                .frame(width: 26, height: 26)
                .background(
                    (isComplete ? purpleAccent.opacity(0.16) : Color.white.opacity(0.05)),
                    in: Circle()
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.white.opacity(0.56))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 10)

            accessory()
        }
        .padding(14)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
        )
    }

    private func statusPill(text: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 5)
        .background(color.opacity(0.12), in: Capsule())
    }
}

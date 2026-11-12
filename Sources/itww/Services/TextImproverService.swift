import Foundation
import FoundationModels

public enum ModelReadiness: Equatable, Sendable {
    case ready(detail: String)
    case unavailable(title: String, guidance: String)

    public var isReady: Bool {
        if case .ready = self { return true }
        return false
    }
}

@MainActor
public final class TextImproverService {
    public static let shared = TextImproverService()

    private init() {}

    public func checkReadiness(preferredBackend: ModelBackend) -> ModelReadiness {
        let onDeviceModel = SystemLanguageModel(
            useCase: .general,
            guardrails: .permissiveContentTransformations
        )

        if preferredBackend == .privateCloudCompute {
            let pccModel = PrivateCloudComputeLanguageModel()
            if pccModel.isAvailable {
                return .ready(detail: "Private Cloud Compute ready")
            }
            if onDeviceModel.isAvailable {
                return .ready(detail: "On-Device Apple Intelligence ready (PCC unavailable)")
            }
        }

        switch onDeviceModel.availability {
        case .available:
            return .ready(detail: "On-Device Apple Intelligence ready")
        case .unavailable(let reason):
            switch reason {
            case .appleIntelligenceNotEnabled:
                return .unavailable(
                    title: "Apple Intelligence is turned off",
                    guidance: "Enable Apple Intelligence & Siri in System Settings, then try again."
                )
            case .modelNotReady:
                return .unavailable(
                    title: "Apple Intelligence model is preparing",
                    guidance: "macOS is still downloading or warming up the local model, or the app is not running from a signed .app bundle."
                )
            case .deviceNotEligible:
                return .unavailable(
                    title: "Mac not eligible for Apple Intelligence",
                    guidance: "Apple Intelligence requires an Apple Silicon Mac with Siri & Apple Intelligence supported."
                )
            @unknown default:
                return .unavailable(
                    title: "Apple Intelligence unavailable",
                    guidance: "Check Apple Intelligence & Siri in System Settings."
                )
            }
        }
    }

    public func prewarmIfPossible(extraRules: String) {
        let model = SystemLanguageModel(
            useCase: .general,
            guardrails: .permissiveContentTransformations
        )
        guard model.isAvailable else { return }
        let session = LanguageModelSession(
            model: model,
            instructions: RewriteMode.improve.systemInstructions(extraRules: extraRules)
        )
        session.prewarm()
    }

    public func streamImprovement(
        sourceText: String,
        mode: RewriteMode,
        customInstruction: String,
        preferredBackend: ModelBackend,
        extraRules: String,
        temperature: Double,
        onPartial: @escaping @MainActor (String) -> Void
    ) async throws -> (text: String, backendUsed: String) {
        let instructions = mode.systemInstructions(
            extraRules: extraRules,
            customInstruction: customInstruction
        )
        let prompt = mode.buildPrompt(
            for: sourceText,
            customInstruction: customInstruction,
            extraRules: extraRules
        )
        let options = GenerationOptions(temperature: temperature)

        if preferredBackend == .privateCloudCompute {
            let pcc = PrivateCloudComputeLanguageModel()
            if pcc.isAvailable {
                do {
                    let text = try await runStream(
                        model: pcc,
                        instructions: instructions,
                        prompt: prompt,
                        options: options,
                        originalText: sourceText,
                        onPartial: onPartial
                    )
                    return (text, "Private Cloud Compute")
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    // Fall back to on-device model if PCC fails due to network, quota, or entitlement.
                }
            }
        }

        let onDevice = SystemLanguageModel(
            useCase: .general,
            guardrails: .permissiveContentTransformations
        )
        guard onDevice.isAvailable else {
            let status = checkReadiness(preferredBackend: preferredBackend)
            if case .unavailable(let title, let guidance) = status {
                throw ImproverError.modelUnavailable("\(title). \(guidance)")
            }
            throw ImproverError.modelUnavailable("Apple Intelligence is currently unavailable.")
        }

        let text = try await runStream(
            model: onDevice,
            instructions: instructions,
            prompt: prompt,
            options: options,
            originalText: sourceText,
            onPartial: onPartial
        )
        return (text, "On-Device")
    }

    private func runStream<M: LanguageModel>(
        model: M,
        instructions: String,
        prompt: String,
        options: GenerationOptions,
        originalText: String,
        onPartial: @escaping @MainActor (String) -> Void
    ) async throws -> String {
        let session = LanguageModelSession(model: model, instructions: instructions)
        let stream = session.streamResponse(to: prompt, options: options)

        var latestRaw = ""
        do {
            for try await snapshot in stream {
                try Task.checkCancellation()
                latestRaw = snapshot.content
                let cleaned = RewriteMode.cleanModelOutput(latestRaw, original: originalText)
                onPartial(cleaned)
            }
            return RewriteMode.cleanModelOutput(latestRaw, original: originalText)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as LanguageModelError {
            throw ImproverError.fromLanguageModelError(error)
        } catch {
            throw ImproverError.generationFailed(error.localizedDescription)
        }
    }
}

public enum ImproverError: LocalizedError {
    case modelUnavailable(String)
    case generationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .modelUnavailable(let detail):
            detail
        case .generationFailed(let detail):
            detail
        }
    }

    static func fromLanguageModelError(_ error: LanguageModelError) -> ImproverError {
        switch error {
        case .contextSizeExceeded(let info):
            return .generationFailed("Selected text is too long (\(info.tokenCount) tokens; limit is \(info.contextSize)). Select a shorter passage.")
        case .guardrailViolation:
            return .generationFailed("Apple Intelligence safety guardrails blocked rewriting this passage.")
        case .refusal:
            return .generationFailed("Apple Intelligence declined to rewrite this text.")
        case .unsupportedLanguageOrLocale:
            return .generationFailed("This language is not yet supported by Apple Intelligence on your Mac.")
        case .rateLimited:
            return .generationFailed("Apple Intelligence rate limit reached. Wait a moment and retry.")
        case .timeout:
            return .generationFailed("Apple Intelligence timed out while generating a response.")
        default:
            return .generationFailed(error.localizedDescription)
        }
    }
}

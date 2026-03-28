import Foundation
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

extension PostProcessingService {
    struct RepairRequestContext {
        let malformedOutput: String
        let transcription: String
        let originalPrompt: PostProcessingPrompt
        let mode: IntelligenceKernelMode
        let systemPromptOverride: String?
        let timeoutSeconds: TimeInterval
        let traceContext: RequestTraceContext
        let attempt: Int
    }

    // MARK: - Legacy Pipeline

    func sendToAI(
        transcription: String,
        prompt: PostProcessingPrompt,
        mode: IntelligenceKernelMode,
        systemPromptOverride: String?,
        requestProfile: RequestProfile,
        traceContext: RequestTraceContext
    ) async throws -> String {
        var lastError: Error?
        let attemptCount = max(1, requestProfile.retryCount + 1)

        for attempt in 0..<attemptCount {
            do {
                return try await performAIRequest(
                    context: ProviderRequestContext(
                        transcription: transcription,
                        prompt: prompt,
                        mode: mode,
                        systemPromptOverride: systemPromptOverride,
                        timeoutSeconds: requestProfile.timeoutSeconds,
                        traceContext: traceContext,
                        attempt: attempt + 1
                    )
                )
            } catch {
                lastError = error

                guard shouldRetry(error: error), attempt < attemptCount - 1 else {
                    throw error
                }

                let delay = retryDelay(for: attempt)
                logRetry(message: "AI request failed, retrying", traceContext: traceContext, attempt: attempt + 1, delay: delay)
                try await Task.sleep(nanoseconds: delay)
            }
        }

        throw lastError ?? PostProcessingError.invalidResponse
    }

    // MARK: - Structured Pipeline

    func sendToAIStructured(
        transcription: String,
        prompt: PostProcessingPrompt,
        mode: IntelligenceKernelMode,
        systemPromptOverride: String?,
        requestProfile: RequestProfile,
        traceContext: RequestTraceContext
    ) async throws -> DomainPostProcessingResult {
        var lastError: Error?
        let structuredPrompt = makeStructuredPrompt(from: prompt)
        let attemptCount = max(1, requestProfile.retryCount + 1)

        for attempt in 0..<attemptCount {
            do {
                let rawOutput = try await performAIRequest(
                    context: ProviderRequestContext(
                        transcription: transcription,
                        prompt: structuredPrompt,
                        mode: mode,
                        systemPromptOverride: systemPromptOverride,
                        timeoutSeconds: requestProfile.timeoutSeconds,
                        traceContext: traceContext,
                        attempt: attempt + 1
                    )
                )

                if let summary = tryParseCanonicalSummary(rawOutput) {
                    return makeStructuredResult(summary, outputState: .structured)
                }

                return try await handleStructuredParseFailure(
                    rawOutput: rawOutput,
                    transcription: transcription,
                    prompt: prompt,
                    mode: mode,
                    systemPromptOverride: systemPromptOverride,
                    requestProfile: requestProfile,
                    traceContext: traceContext,
                    attempt: attempt + 1
                )
            } catch {
                lastError = error

                guard shouldRetry(error: error), attempt < attemptCount - 1 else {
                    throw error
                }

                let delay = retryDelay(for: attempt)
                logRetry(
                    message: "Structured AI request failed, retrying",
                    traceContext: traceContext,
                    attempt: attempt + 1,
                    delay: delay
                )
                try await Task.sleep(nanoseconds: delay)
            }
        }

        throw lastError ?? PostProcessingError.invalidResponse
    }

    func makeStructuredPrompt(from prompt: PostProcessingPrompt) -> PostProcessingPrompt {
        var structuredPrompt = prompt
        structuredPrompt.promptText = summaryPromptComposer.structuredPrompt(from: prompt.promptText)
        return structuredPrompt
    }

    func tryParseCanonicalSummary(_ output: String) -> CanonicalSummary? {
        try? summaryResponseParser.parse(from: output)
    }

    func makeStructuredResult(
        _ summary: CanonicalSummary,
        outputState: DomainPostProcessingOutputState
    ) -> DomainPostProcessingResult {
        DomainPostProcessingResult(
            processedText: summaryRenderer.render(summary),
            canonicalSummary: summary,
            outputState: outputState
        )
    }

    func performRepairRequest(context: RepairRequestContext) async throws -> String {
        let baseSystemPrompt = context.systemPromptOverride ?? settings.systemPrompt
        let systemPrompt = summaryRepairComposer.systemPrompt(basePrompt: baseSystemPrompt)
        let userPrompt = summaryRepairComposer.userMessage(
            malformedOutput: context.malformedOutput,
            transcription: context.transcription,
            originalPrompt: context.originalPrompt.promptText
        )

        return try await performCustomAIRequest(
            context: CustomProviderRequestContext(
                mode: context.mode,
                systemPrompt: systemPrompt,
                userContent: userPrompt,
                timeoutSeconds: context.timeoutSeconds,
                traceContext: context.traceContext,
                attempt: context.attempt
            )
        )
    }

    private func handleStructuredParseFailure(
        rawOutput: String,
        transcription: String,
        prompt: PostProcessingPrompt,
        mode: IntelligenceKernelMode,
        systemPromptOverride: String?,
        requestProfile: RequestProfile,
        traceContext: RequestTraceContext,
        attempt: Int
    ) async throws -> DomainPostProcessingResult {
        AppLogger.warning(
            "Structured summary parse failed, attempting repair",
            category: .transcriptionEngine,
            extra: traceExtra(from: traceContext, attempt: attempt, elapsedMilliseconds: nil)
        )

        if requestProfile.useRepair,
           let repairedOutput = try? await performRepairRequest(
               context: RepairRequestContext(
                   malformedOutput: rawOutput,
                   transcription: transcription,
                   originalPrompt: prompt,
                   mode: mode,
                   systemPromptOverride: systemPromptOverride,
                   timeoutSeconds: requestProfile.timeoutSeconds,
                   traceContext: traceContext,
                   attempt: attempt
               )
           ),
           let repairedSummary = tryParseCanonicalSummary(repairedOutput)
        {
            return makeStructuredResult(repairedSummary, outputState: .repaired)
        }

        AppLogger.warning(
            "Structured summary repair failed, using deterministic fallback",
            category: .transcriptionEngine,
            extra: traceExtra(from: traceContext, attempt: attempt, elapsedMilliseconds: nil)
        )
        return summaryFallbackBuilder.build(providerOutput: rawOutput, transcription: transcription)
    }

    private func retryDelay(for attempt: Int) -> UInt64 {
        let multiplier = Int(pow(2.0, Double(attempt)))
        return Constants.baseRetryDelay * UInt64(multiplier)
    }

    private func logRetry(message: String, traceContext: RequestTraceContext, attempt: Int, delay: UInt64) {
        AppLogger.warning(
            message,
            category: .transcriptionEngine,
            extra: traceExtra(
                from: traceContext,
                attempt: attempt,
                elapsedMilliseconds: nil,
                extra: ["delay_ms": delay / 1_000_000]
            )
        )
    }
}

import Darwin
import Foundation

struct RustAudioKernelFFI: @unchecked Sendable {
    enum ResultCode: Int32 {
        case ok = 0
        case nullPointer = 1
        case invalidArgument = 2
    }

    struct RmsPeakResult {
        let rmsLinear: Float
        let peakLinear: Float
    }

    typealias VersionFunction = @convention(c) () -> UInt32
    typealias ComputeRmsPeakFunction = @convention(c) (
        UnsafePointer<Float>?,
        Int,
        UnsafeMutableRawPointer?
    ) -> Int32

    private let versionImpl: VersionFunction
    private let computeRmsPeakImpl: ComputeRmsPeakFunction

    init(
        versionImpl: @escaping VersionFunction,
        computeRmsPeakImpl: @escaping ComputeRmsPeakFunction
    ) {
        self.versionImpl = versionImpl
        self.computeRmsPeakImpl = computeRmsPeakImpl
    }

    func version() -> UInt32 {
        return versionImpl()
    }

    func computeRmsPeak(samples: [Float]) -> RmsPeakResult? {
        guard !samples.isEmpty else { return nil }

        var ffiResult = AKRmsPeakResult(rms_linear: 0, peak_linear: 0)
        let ffiCode = samples.withUnsafeBufferPointer { buffer in
            withUnsafeMutablePointer(to: &ffiResult) { resultPointer in
                computeRmsPeakImpl(buffer.baseAddress, buffer.count, UnsafeMutableRawPointer(resultPointer))
            }
        }

        guard ResultCode(rawValue: ffiCode) == .ok else {
            return nil
        }

        return RmsPeakResult(
            rmsLinear: ffiResult.rms_linear,
            peakLinear: ffiResult.peak_linear
        )
    }
}

struct AKRmsPeakResult {
    var rms_linear: Float
    var peak_linear: Float
}

extension RustAudioKernelFFI {
    static func loadFromProcessSymbols() -> RustAudioKernelFFI? {
        if let ffi = loadFromSymbols(symbolHandle: UnsafeMutableRawPointer(bitPattern: -2)) {
            return ffi
        }

        return loadFromBundledDynamicLibrary()
    }

    private static func loadFromSymbols(symbolHandle: UnsafeMutableRawPointer?) -> RustAudioKernelFFI? {
        guard let versionSymbol = dlsym(symbolHandle, "ak_version"),
              let rmsPeakSymbol = dlsym(symbolHandle, "ak_compute_rms_peak_f32")
        else {
            return nil
        }

        let versionImpl = unsafeBitCast(versionSymbol, to: VersionFunction.self)
        let computeRmsPeakImpl = unsafeBitCast(rmsPeakSymbol, to: ComputeRmsPeakFunction.self)

        return RustAudioKernelFFI(
            versionImpl: versionImpl,
            computeRmsPeakImpl: computeRmsPeakImpl
        )
    }

    private static func loadFromBundledDynamicLibrary() -> RustAudioKernelFFI? {
        let loadFlags = RTLD_NOW | RTLD_LOCAL
        for libraryPath in bundledLibraryCandidatePaths() {
            guard let handle = dlopen(libraryPath, loadFlags) else {
                continue
            }

            guard let ffi = loadFromSymbols(symbolHandle: handle) else {
                dlclose(handle)
                continue
            }

            return ffi
        }

        return nil
    }

    private static func bundledLibraryCandidatePaths() -> [String] {
        let libraryName = "libaudio_kernels_rust.dylib"
        var paths: [String] = []

        let envPath = ProcessInfo.processInfo.environment["MA_RUST_AUDIO_KERNELS_DYLIB_PATH"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let envPath, !envPath.isEmpty {
            paths.append(envPath)
        }

        if let frameworksURL = Bundle.main.privateFrameworksURL {
            paths.append(frameworksURL.appendingPathComponent(libraryName).path)
        }

        if let executableURL = Bundle.main.executableURL {
            let frameworkURL = executableURL
                .deletingLastPathComponent()
                .appendingPathComponent("../Frameworks/\(libraryName)")
                .standardizedFileURL
            paths.append(frameworkURL.path)
        }

        var seen = Set<String>()
        return paths.filter { seen.insert($0).inserted }
    }
}

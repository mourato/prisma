import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

public struct GenerateMockMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let protocolDecl = declaration.as(ProtocolDeclSyntax.self) else {
            return []
        }

        let protocolName = protocolDecl.name.text
        let mockName = "MacroMock\(protocolName)"

        var members: [DeclSyntax] = []

        for member in protocolDecl.memberBlock.members {
            guard let functionDecl = member.decl.as(FunctionDeclSyntax.self) else {
                continue
            }

            let signature = functionDecl.signature
            let functionName = functionDecl.name.text

            let params = signature.parameterClause.parameters
            let paramDecls: [ParameterDecl] = params.map { ParameterDecl(from: $0) }

            let key = functionKey(name: functionName, parameters: paramDecls)
            let keyPascal = pascalCase(from: key)

            let argsTypealiasName = "\(keyPascal)Args"

            if !paramDecls.isEmpty {
                let argsType = argsTypeString(from: paramDecls)
                let argsValue = argsValueString(from: paramDecls)

                members.append(
                    DeclSyntax(
                        """
                        typealias \(raw: argsTypealiasName) = \(raw: argsType)
                        """
                    )
                )

                members.append(
                    DeclSyntax(
                        """
                        private(set) var \(raw: key)Calls: [\(raw: argsTypealiasName)] = []
                        """
                    )
                )

                members.append(
                    DeclSyntax(
                        """
                        var \(raw: key)Handler: (\(raw: handlerTypeString(from: signature, parameters: paramDecls)))?
                        """
                    )
                )

                members.append(
                    DeclSyntax(
                        """
                        \(raw: functionSignatureSource(from: functionDecl)) {
                            \(raw: key)Calls.append(\(raw: argsValue))
                            guard let handler = \(raw: key)Handler else {
                                fatalError("Unhandled call to \(raw: functionName)")
                            }
                            \(raw: handlerCallSource(signature: signature, callArgs: callArgsString(from: paramDecls)))
                        }
                        """
                    )
                )

                continue
            }

            // Zero-parameter function
            members.append(
                DeclSyntax(
                    """
                    private(set) var \(raw: key)CallCount: Int = 0
                    """
                )
            )

            members.append(
                DeclSyntax(
                    """
                    var \(raw: key)Handler: (\(raw: handlerTypeString(from: signature, parameters: paramDecls)))?
                    """
                )
            )

            members.append(
                DeclSyntax(
                    """
                    \(raw: functionSignatureSource(from: functionDecl)) {
                        \(raw: key)CallCount += 1
                        guard let handler = \(raw: key)Handler else {
                            fatalError("Unhandled call to \(raw: functionName)")
                        }
                        \(raw: handlerCallSource(signature: signature, callArgs: callArgsString(from: paramDecls)))
                    }
                    """
                )
            )
        }

        let memberBlock = members.map { $0.description }.joined(separator: "\n\n")

        return [
            DeclSyntax(
                """
                #if DEBUG
                final class \(raw: mockName): \(raw: protocolName), @unchecked Sendable {
                \(raw: memberBlock)
                }
                #endif
                """
            ),
        ]
    }
}

private struct ParameterDecl {
    let externalName: String?
    let internalName: String
    let type: String

    init(from parameter: FunctionParameterSyntax) {
        let firstName = parameter.firstName.text
        if firstName != "_" {
            externalName = firstName
        } else {
            externalName = nil
        }

        internalName = parameter.secondName?.text ?? firstName
        type = parameter.type.trimmedDescription
    }

    var labelForKey: String {
        if let externalName {
            return externalName
        }
        return internalName
    }
}

private func functionKey(name: String, parameters: [ParameterDecl]) -> String {
    if parameters.isEmpty {
        return name
    }

    let labels = parameters
        .map(\.labelForKey)
        .map { $0 == "_" ? "arg" : $0 }
        .map { $0.replacingOccurrences(of: "-", with: "_") }

    return ([name] + labels).joined(separator: "_")
}

private func pascalCase(from key: String) -> String {
    let parts = key.split(separator: "_").map(String.init)
    let transformed = parts.map { part in
        guard let first = part.first else { return part }
        return String(first).uppercased() + part.dropFirst()
    }
    return transformed.joined()
}

private func argsTypeString(from params: [ParameterDecl]) -> String {
    if params.isEmpty {
        return "Void"
    }

    if params.count == 1 {
        return params[0].type
    }

    let pieces = params.map { p in
        let label = p.externalName ?? p.internalName
        return "\(label): \(p.type)"
    }
    return "(\(pieces.joined(separator: ", ")))"
}

private func argsValueString(from params: [ParameterDecl]) -> String {
    if params.isEmpty {
        return "()"
    }

    if params.count == 1 {
        return params[0].internalName
    }

    let pieces = params.map { p in
        let label = p.externalName ?? p.internalName
        return "\(label): \(p.internalName)"
    }
    return "(\(pieces.joined(separator: ", ")))"
}

private func callArgsString(from params: [ParameterDecl]) -> String {
    params.map(\.internalName).joined(separator: ", ")
}

private func handlerTypeString(from signature: FunctionSignatureSyntax, parameters: [ParameterDecl]) -> String {
    let paramTypes = parameters.map(\.type).joined(separator: ", ")
    let paramsSource = "(\(paramTypes))"

    let asyncSource = signature.effectSpecifiers?.asyncSpecifier != nil ? " async" : ""
    let throwsSource = signature.effectSpecifiers?.throwsClause != nil ? " throws" : ""

    let returnType = signature.returnClause?.type.trimmedDescription ?? "Void"
    return "\(paramsSource)\(asyncSource)\(throwsSource) -> \(returnType)"
}

private func functionSignatureSource(from functionDecl: FunctionDeclSyntax) -> String {
    let name = functionDecl.name.text
    let signature = functionDecl.signature.trimmedDescription
    return "func \(name)\(signature)"
}

private func handlerCallSource(signature: FunctionSignatureSyntax, callArgs: String) -> String {
    let asyncKeyword = signature.effectSpecifiers?.asyncSpecifier != nil
    let throwsKeyword = signature.effectSpecifiers?.throwsClause != nil

    switch (asyncKeyword, throwsKeyword) {
    case (true, true):
        return "return try await handler(\(callArgs))"
    case (true, false):
        return "return await handler(\(callArgs))"
    case (false, true):
        return "return try handler(\(callArgs))"
    case (false, false):
        return "return handler(\(callArgs))"
    }
}

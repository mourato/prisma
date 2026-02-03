import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

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

            let argsTupleTypealiasName = "\(functionName.prefix(1).uppercased())\(functionName.dropFirst())Args"
            let argsTupleType = tupleType(from: paramDecls)
            let argsTupleValue = tupleValue(from: paramDecls)

            if !paramDecls.isEmpty {
                members.append(
                    DeclSyntax(
                        """
                        typealias \(raw: argsTupleTypealiasName) = \(raw: argsTupleType)
                        """
                    )
                )
                members.append(
                    DeclSyntax(
                        """
                        private(set) var \(raw: functionName)Calls: [\(raw: argsTupleTypealiasName)] = []
                        """
                    )
                )
                members.append(
                    DeclSyntax(
                        """
                        private(set) var \(raw: functionName)CallCount: Int = 0
                        """
                    )
                )
            }

            let handlerType = functionHandlerType(from: signature, parameters: paramDecls)
            members.append(
                DeclSyntax(
                    """
                    var \(raw: functionName)Handler: \(raw: handlerType)?
                    """
                )
            )

            let functionSignatureSource = functionSignatureSource(from: functionDecl)
            let functionBody = functionBodySource(
                functionName: functionName,
                signature: signature,
                paramDecls: paramDecls,
                argsTupleValue: argsTupleValue
            )

            members.append(
                DeclSyntax(
                    """
                    \(raw: functionSignatureSource) {
                    \(raw: functionBody)
                    }
                    """
                )
            )
        }

        let memberBlock = members.map(\.description).joined(separator: "\n\n")

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
}

private func tupleType(from params: [ParameterDecl]) -> String {
    if params.isEmpty { return "Void" }
    let pieces = params.map { p in
        let label = p.externalName ?? p.internalName
        return "\(label): \(p.type)"
    }
    return "(\(pieces.joined(separator: ", ")))"
}

private func tupleValue(from params: [ParameterDecl]) -> String {
    if params.isEmpty { return "()" }
    let pieces = params.map { p in
        let label = p.externalName ?? p.internalName
        return "\(label): \(p.internalName)"
    }
    return "(\(pieces.joined(separator: ", ")))"
}

private func functionHandlerType(from signature: FunctionSignatureSyntax, parameters: [ParameterDecl]) -> String {
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

private func functionBodySource(
    functionName: String,
    signature: FunctionSignatureSyntax,
    paramDecls: [ParameterDecl],
    argsTupleValue: String
) -> String {
    let asyncKeyword = signature.effectSpecifiers?.asyncSpecifier != nil
    let throwsKeyword = signature.effectSpecifiers?.throwsClause != nil

    let recordLine: String
    if paramDecls.isEmpty {
        recordLine = "\(functionName)CallCount += 1"
    } else {
        recordLine = "\(functionName)Calls.append(\(argsTupleValue))"
    }

    let callArgs = paramDecls.map(\.internalName).joined(separator: ", ")

    let handlerCall = switch (asyncKeyword, throwsKeyword) {
    case (true, true):
        "return try await handler(\(callArgs))"
    case (true, false):
        "return await handler(\(callArgs))"
    case (false, true):
        "return try handler(\(callArgs))"
    case (false, false):
        "return handler(\(callArgs))"
    }

    return """
    \(recordLine)
    guard let handler = \(functionName)Handler else {
        fatalError("Unhandled call to \(functionName)")
    }
    \(handlerCall)
    """
}

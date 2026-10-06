import Foundation
import PackagePlugin

/// Compiles `wp_com_credentials.json`, in the package's root, into the target it's applied to as `CompiledCredentials`,
/// with `generate-credentials`. The file is an input only while it exists, so adding, changing or removing it
/// regenerates `CompiledCredentials`.
@main
struct CredentialsPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        let json = context.package.directoryURL.appending(path: "wp_com_credentials.json")
        let swift = context.pluginWorkDirectoryURL.appending(path: "CompiledCredentials.swift")
        let exists = FileManager.default.fileExists(atPath: json.path(percentEncoded: false))
        return [
            .buildCommand(
                displayName: "Compiling in the WordPress.com OAuth client",
                executable: try context.tool(named: "generate-credentials").url,
                arguments: [json.path(percentEncoded: false), swift.path(percentEncoded: false)],
                inputFiles: exists ? [json] : [],
                outputFiles: [swift]
            )
        ]
    }
}

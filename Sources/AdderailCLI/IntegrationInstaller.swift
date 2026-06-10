import Foundation

struct IntegrationInstaller {
    private let launchAgentInstaller: LaunchAgentInstaller
    private let claudeSettingsURL: URL
    private let codexHooksURL: URL
    private let piExtensionURL: URL

    init(
        launchAgentInstaller: LaunchAgentInstaller = LaunchAgentInstaller(),
        claudeSettingsURL: URL = ClaudeHookSettingsInstaller.defaultSettingsURL(),
        codexHooksURL: URL = CodexHookSettingsInstaller.defaultHooksURL(),
        piExtensionURL: URL = PiExtensionInstaller.defaultExtensionURL()
    ) {
        self.launchAgentInstaller = launchAgentInstaller
        self.claudeSettingsURL = claudeSettingsURL
        self.codexHooksURL = codexHooksURL
        self.piExtensionURL = piExtensionURL
    }

    func install(_ provider: IntegrationProvider) throws -> IntegrationInstallResult {
        switch provider {
        case .claude:
            return .claude(try installClaude())
        case .codex:
            return .codex(try installCodex())
        case .pi:
            return .pi(try installPi())
        }
    }

    func uninstall(_ provider: IntegrationProvider) throws -> IntegrationUninstallResult {
        switch provider {
        case .claude:
            return .claude(try uninstallClaude())
        case .codex:
            return .codex(try uninstallCodex())
        case .pi:
            return .pi(try uninstallPi())
        }
    }

    private func installClaude() throws -> ClaudeIntegrationInstallResult {
        let hookInstaller = ClaudeHookSettingsInstaller(
            settingsURL: claudeSettingsURL,
            adderailURL: launchAgentInstaller.cliURL
        )
        let hadInstalledIntegration = hasInstalledIntegration()
        let hookPlan = try hookInstaller.prepareInstall()
        let launchAgentResult = try launchAgentInstaller.install()
        let hookResult: ClaudeHookSettingsChange

        do {
            hookResult = try hookInstaller.install(preparedPlan: hookPlan)
        } catch {
            if hadInstalledIntegration == false {
                _ = try? launchAgentInstaller.uninstall()
            }
            throw error
        }

        return ClaudeIntegrationInstallResult(
            launchAgentResult: launchAgentResult,
            hookResult: hookResult
        )
    }

    private func installCodex() throws -> CodexIntegrationInstallResult {
        let hookInstaller = CodexHookSettingsInstaller(
            hooksURL: codexHooksURL,
            adderailURL: launchAgentInstaller.cliURL
        )
        let hadInstalledIntegration = hasInstalledIntegration()
        let hookPlan = try hookInstaller.prepareInstall()
        let launchAgentResult = try launchAgentInstaller.install()
        let hookResult: CodexHookSettingsChange

        do {
            hookResult = try hookInstaller.install(preparedPlan: hookPlan)
        } catch {
            if hadInstalledIntegration == false {
                _ = try? launchAgentInstaller.uninstall()
            }
            throw error
        }

        return CodexIntegrationInstallResult(
            launchAgentResult: launchAgentResult,
            hookResult: hookResult
        )
    }

    private func installPi() throws -> PiIntegrationInstallResult {
        let extensionInstaller = PiExtensionInstaller(
            extensionURL: piExtensionURL,
            adderailURL: launchAgentInstaller.cliURL
        )
        let hadInstalledIntegration = hasInstalledIntegration()
        let extensionPlan = try extensionInstaller.prepareInstall()
        let launchAgentResult = try launchAgentInstaller.install()
        let extensionResult: PiExtensionChange

        do {
            extensionResult = try extensionInstaller.install(preparedPlan: extensionPlan)
        } catch {
            if hadInstalledIntegration == false {
                _ = try? launchAgentInstaller.uninstall()
            }
            throw error
        }

        return PiIntegrationInstallResult(
            launchAgentResult: launchAgentResult,
            extensionResult: extensionResult
        )
    }

    private func uninstallClaude() throws -> ClaudeIntegrationUninstallResult {
        let hookResult = try ClaudeHookSettingsInstaller(
            settingsURL: claudeSettingsURL,
            adderailURL: launchAgentInstaller.cliURL
        ).uninstall()
        let launchAgentResult = try uninstallLaunchAgentIfNoIntegrationsRemain(excluding: .claude)

        return ClaudeIntegrationUninstallResult(
            hookResult: hookResult,
            launchAgentResult: launchAgentResult
        )
    }

    private func uninstallCodex() throws -> CodexIntegrationUninstallResult {
        let hookResult = try CodexHookSettingsInstaller(
            hooksURL: codexHooksURL,
            adderailURL: launchAgentInstaller.cliURL
        ).uninstall()
        let launchAgentResult = try uninstallLaunchAgentIfNoIntegrationsRemain(excluding: .codex)

        return CodexIntegrationUninstallResult(
            hookResult: hookResult,
            launchAgentResult: launchAgentResult
        )
    }

    private func uninstallPi() throws -> PiIntegrationUninstallResult {
        let extensionResult = try PiExtensionInstaller(
            extensionURL: piExtensionURL,
            adderailURL: launchAgentInstaller.cliURL
        ).uninstall()
        let launchAgentResult = try uninstallLaunchAgentIfNoIntegrationsRemain(excluding: .pi)

        return PiIntegrationUninstallResult(
            extensionResult: extensionResult,
            launchAgentResult: launchAgentResult
        )
    }

    private func uninstallLaunchAgentIfNoIntegrationsRemain(excluding provider: IntegrationProvider) throws -> LaunchAgentUninstallResult? {
        if hasInstalledIntegration(excluding: provider) {
            return nil
        }

        return try launchAgentInstaller.uninstall()
    }

    private func hasInstalledIntegration(excluding provider: IntegrationProvider? = nil) -> Bool {
        for candidate in IntegrationProvider.allCases where candidate != provider {
            do {
                if try isInstalled(candidate) {
                    return true
                }
            } catch {
                return true
            }
        }

        return false
    }

    private func isInstalled(_ provider: IntegrationProvider) throws -> Bool {
        switch provider {
        case .claude:
            return try ClaudeHookSettingsInstaller(
                settingsURL: claudeSettingsURL,
                adderailURL: launchAgentInstaller.cliURL
            ).isInstalled()
        case .codex:
            return try CodexHookSettingsInstaller(
                hooksURL: codexHooksURL,
                adderailURL: launchAgentInstaller.cliURL
            ).isInstalled()
        case .pi:
            return try PiExtensionInstaller(
                extensionURL: piExtensionURL,
                adderailURL: launchAgentInstaller.cliURL
            ).isInstalled()
        }
    }
}

enum IntegrationInstallResult {
    case claude(ClaudeIntegrationInstallResult)
    case codex(CodexIntegrationInstallResult)
    case pi(PiIntegrationInstallResult)
}

enum IntegrationUninstallResult {
    case claude(ClaudeIntegrationUninstallResult)
    case codex(CodexIntegrationUninstallResult)
    case pi(PiIntegrationUninstallResult)
}

struct ClaudeIntegrationInstallResult {
    let launchAgentResult: LaunchAgentInstallResult
    let hookResult: ClaudeHookSettingsChange
}

struct ClaudeIntegrationUninstallResult {
    let hookResult: ClaudeHookSettingsChange
    let launchAgentResult: LaunchAgentUninstallResult?
}

struct CodexIntegrationInstallResult {
    let launchAgentResult: LaunchAgentInstallResult
    let hookResult: CodexHookSettingsChange
}

struct CodexIntegrationUninstallResult {
    let hookResult: CodexHookSettingsChange
    let launchAgentResult: LaunchAgentUninstallResult?
}

struct PiIntegrationInstallResult {
    let launchAgentResult: LaunchAgentInstallResult
    let extensionResult: PiExtensionChange
}

struct PiIntegrationUninstallResult {
    let extensionResult: PiExtensionChange
    let launchAgentResult: LaunchAgentUninstallResult?
}

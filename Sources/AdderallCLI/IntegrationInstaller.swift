import Foundation

struct IntegrationInstaller {
    private let launchAgentInstaller: LaunchAgentInstaller
    private let claudeSettingsURL: URL
    private let piExtensionURL: URL

    init(
        launchAgentInstaller: LaunchAgentInstaller = LaunchAgentInstaller(),
        claudeSettingsURL: URL = ClaudeHookSettingsInstaller.defaultSettingsURL(),
        piExtensionURL: URL = PiExtensionInstaller.defaultExtensionURL()
    ) {
        self.launchAgentInstaller = launchAgentInstaller
        self.claudeSettingsURL = claudeSettingsURL
        self.piExtensionURL = piExtensionURL
    }

    func install(_ provider: IntegrationProvider) throws -> IntegrationInstallResult {
        switch provider {
        case .claude:
            return .claude(try installClaude())
        case .pi:
            return .pi(try installPi())
        }
    }

    func uninstall(_ provider: IntegrationProvider) throws -> IntegrationUninstallResult {
        switch provider {
        case .claude:
            return .claude(try uninstallClaude())
        case .pi:
            return .pi(try uninstallPi())
        }
    }

    private func installClaude() throws -> ClaudeIntegrationInstallResult {
        let hookInstaller = ClaudeHookSettingsInstaller(
            settingsURL: claudeSettingsURL,
            adderallURL: launchAgentInstaller.cliURL
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

    private func installPi() throws -> PiIntegrationInstallResult {
        let extensionInstaller = PiExtensionInstaller(
            extensionURL: piExtensionURL,
            adderallURL: launchAgentInstaller.cliURL
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
            adderallURL: launchAgentInstaller.cliURL
        ).uninstall()
        let launchAgentResult = try uninstallLaunchAgentIfNoIntegrationsRemain(excluding: .claude)

        return ClaudeIntegrationUninstallResult(
            hookResult: hookResult,
            launchAgentResult: launchAgentResult
        )
    }

    private func uninstallPi() throws -> PiIntegrationUninstallResult {
        let extensionResult = try PiExtensionInstaller(
            extensionURL: piExtensionURL,
            adderallURL: launchAgentInstaller.cliURL
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
        for candidate in [IntegrationProvider.claude, .pi] where candidate != provider {
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
                adderallURL: launchAgentInstaller.cliURL
            ).isInstalled()
        case .pi:
            return try PiExtensionInstaller(
                extensionURL: piExtensionURL,
                adderallURL: launchAgentInstaller.cliURL
            ).isInstalled()
        }
    }
}

enum IntegrationInstallResult {
    case claude(ClaudeIntegrationInstallResult)
    case pi(PiIntegrationInstallResult)
}

enum IntegrationUninstallResult {
    case claude(ClaudeIntegrationUninstallResult)
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

struct PiIntegrationInstallResult {
    let launchAgentResult: LaunchAgentInstallResult
    let extensionResult: PiExtensionChange
}

struct PiIntegrationUninstallResult {
    let extensionResult: PiExtensionChange
    let launchAgentResult: LaunchAgentUninstallResult?
}

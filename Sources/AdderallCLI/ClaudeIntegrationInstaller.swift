import Foundation

struct ClaudeIntegrationInstaller {
    private let launchAgentInstaller: LaunchAgentInstaller
    private let settingsURL: URL

    init(
        launchAgentInstaller: LaunchAgentInstaller = LaunchAgentInstaller(),
        settingsURL: URL = ClaudeHookSettingsInstaller.defaultSettingsURL()
    ) {
        self.launchAgentInstaller = launchAgentInstaller
        self.settingsURL = settingsURL
    }

    func install() throws -> ClaudeIntegrationInstallResult {
        let hookInstaller = ClaudeHookSettingsInstaller(
            settingsURL: settingsURL,
            adderallURL: launchAgentInstaller.cliURL
        )
        let hookPlan = try hookInstaller.prepareInstall()
        let launchAgentResult = try launchAgentInstaller.install()
        let hookResult: ClaudeHookSettingsChange

        do {
            hookResult = try hookInstaller.install(preparedPlan: hookPlan)
        } catch {
            _ = try? launchAgentInstaller.uninstall()
            throw error
        }

        return ClaudeIntegrationInstallResult(
            launchAgentResult: launchAgentResult,
            hookResult: hookResult
        )
    }

    func uninstall() throws -> ClaudeIntegrationUninstallResult {
        let hookResult = try ClaudeHookSettingsInstaller(
            settingsURL: settingsURL,
            adderallURL: launchAgentInstaller.cliURL
        ).uninstall()
        let launchAgentResult = try launchAgentInstaller.uninstall()

        return ClaudeIntegrationUninstallResult(
            launchAgentResult: launchAgentResult,
            hookResult: hookResult
        )
    }
}

struct ClaudeIntegrationInstallResult {
    let launchAgentResult: LaunchAgentInstallResult
    let hookResult: ClaudeHookSettingsChange
}

struct ClaudeIntegrationUninstallResult {
    let launchAgentResult: LaunchAgentUninstallResult
    let hookResult: ClaudeHookSettingsChange
}

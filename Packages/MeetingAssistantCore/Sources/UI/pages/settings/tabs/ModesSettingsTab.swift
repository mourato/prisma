import SwiftUI

public struct ModesSettingsTab: View {
    public init() {}

    public var body: some View {
        rootPage
    }

    private var rootPage: some View {
        SettingsScrollableContent {
            StylesSettingsTab(embedded: true)

        }
    }
}

#Preview {
    ModesSettingsTab()
}

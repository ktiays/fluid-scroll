//
//  Created by ktiays on 2023/9/7.
//  Copyright (c) 2023 ktiays. All rights reserved.
//

import SwiftUI

struct SettingsView: View {
    
    @ObservedObject private var configuration: ScrollConfiguration
    
    init(configuration: ScrollConfiguration) {
        self.configuration = configuration
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    _ChangableValue(title: "Deceleration Rate", value: $configuration.horizontalDecelerationRate, range: 0.95...0.999)
                    _ChangableValue(title: "Bounce Response", value: $configuration.horizontalBounceResponse, range: 0.01...5)
                    _SetDefaultButton {
                        withAnimation {
                            configuration.horizontalDecelerationRate = UIScrollView.DecelerationRate.normal.rawValue
                            configuration.horizontalBounceResponse = 0.575
                            configuration.objectWillChange.send()
                        }
                    }
                } header: {
                    Text("Horizontal")
                }
                Section {
                    _ChangableValue(title: "Deceleration Rate", value: $configuration.verticalDecelerationRate, range: 0.95...0.999)
                    _ChangableValue(title: "Bounce Response", value: $configuration.verticalBounceResponse, range: 0.01...5)
                    _SetDefaultButton {
                        withAnimation {
                            configuration.verticalDecelerationRate = UIScrollView.DecelerationRate.normal.rawValue
                            configuration.verticalBounceResponse = 0.575
                            configuration.objectWillChange.send()
                        }
                    }
                } header: {
                    Text("Vertical")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct _ChangableValue<S, T>: View where S: StringProtocol, T: BinaryFloatingPoint, T.Stride: BinaryFloatingPoint, T: CVarArg {
    private let title: S
    @Binding private var value: T
    private let range: ClosedRange<T>
    private let onEditingChanged: (Bool) -> Void
    
    init(title: S, value: Binding<T>, range: ClosedRange<T>, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        self.title = title
        _value = value
        self.range = range
        self.onEditingChanged = onEditingChanged
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.3f", value))
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background {
                        RoundedRectangle(cornerRadius: 4)
                            .foregroundStyle(Color.blue.opacity(0.12))
                    }
            }
            Slider(
                value: $value,
                in: range,
                onEditingChanged: onEditingChanged
            )
        }
        .padding(.vertical, 3)
    }
}

struct _SetDefaultButton: View {
    private let action: () -> Void
    
    init(action: @escaping () -> Void) {
        self.action = action
    }
    
    var body: some View {
        Button(action: action, label: {
            Text("Set to Default")
                .foregroundStyle(.blue)
                .opacity(0.8)
        })
    }
}

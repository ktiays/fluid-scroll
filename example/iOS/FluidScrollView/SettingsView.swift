// Copyright (C) 2023 ktiays
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import SwiftUI

struct SettingsView: View {
    
    @ObservedObject private var configuration: ScrollConfiguration
    @Environment(\.dismiss) private var dismiss
    
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
            .toolbar {
                Button(action: {
                    dismiss()
                }, label: {
                    Text("Done")
                })
            }
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

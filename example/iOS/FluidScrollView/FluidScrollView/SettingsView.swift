//
//  Created by ktiays on 2023/9/7.
//  Copyright (c) 2023 ktiays. All rights reserved.
// 

import SwiftUI

struct SettingsView: View {
    
    @State private var horizontalDecelerationRate: CGFloat = UIScrollView.DecelerationRate.normal.rawValue
    @State private var verticalDecelerationRate: CGFloat = UIScrollView.DecelerationRate.normal.rawValue
    
    private let horizontalRateCallback: (CGFloat) -> Void
    private let verticalRateCallback: (CGFloat) -> Void
    private let horizontalResponseCallback: (CGFloat) -> Void
    private let verticalResponseCallback: (CGFloat) -> Void
    
    init(
        horizontalDecelerationRateDidChange: @escaping (CGFloat) -> Void,
        horizontalBounceResponseDidChange: @escaping (CGFloat) -> Void,
        verticalDecelerationRateDidChange: @escaping (CGFloat) -> Void,
        verticalBounceResponseDidChange: @escaping (CGFloat) -> Void
    ) {
        horizontalRateCallback = horizontalDecelerationRateDidChange
        horizontalResponseCallback = horizontalBounceResponseDidChange
        verticalRateCallback = verticalDecelerationRateDidChange
        verticalResponseCallback = verticalBounceResponseDidChange
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading) {
                        Text("Deceleration Rate")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Slider(
                            value: $horizontalDecelerationRate,
                            in: 0.01...0.999,
                            onEditingChanged: { _ in
                                horizontalRateCallback(horizontalDecelerationRate)
                            }
                        )
                        Text(String(format: "%.3f", horizontalDecelerationRate))
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background {
                                RoundedRectangle(cornerRadius: 4)
                                    .foregroundStyle(Color.blue.opacity(0.12))
                            }
                    }
                } header: {
                    Text("Horizontal")
                }
                Section {
                    
                } header: {
                    Text("Vertical")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

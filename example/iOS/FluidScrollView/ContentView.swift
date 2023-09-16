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
import UIKit
import ObjectiveC

extension UIHostingController {
    func ignoresSafeArea() {
        guard let viewClass = object_getClass(view) else {
            return
        }

        let viewSubclassName = String(cString: class_getName(viewClass)).appending("_IgnoreSafeArea")

        if let viewSubclass = NSClassFromString(viewSubclassName) {
            object_setClass(view, viewSubclass)
        } else {
            guard let viewClassNameUtf8 = (viewSubclassName as NSString).utf8String,
                  let viewSubclass = objc_allocateClassPair(viewClass, viewClassNameUtf8, 0) 
            else {
                return
            }

            if let method = class_getInstanceMethod(UIView.self, #selector(getter: UIView.safeAreaInsets)) {
                let safeAreaInsets: @convention(block) (AnyObject) -> UIEdgeInsets = { _ in
                    return .zero
                }

                class_addMethod(
                    viewSubclass,
                    #selector(getter: UIView.safeAreaInsets),
                    imp_implementationWithBlock(safeAreaInsets),
                    method_getTypeEncoding(method)
                )
            }

            objc_registerClassPair(viewSubclass)
            object_setClass(view, viewSubclass)
        }
    }
}

extension View {
    func makeUIView() -> UIView {
        let controller = UIHostingController(rootView: self)
        controller.view.backgroundColor = .clear
        controller.ignoresSafeArea()
        return controller.view
    }
}

struct ContentView: View {
    
    private let icons = ["eject.fill", "pc", "figure.wave", "snowflake"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                ForEach(0..<4, id: \.self) { index in
                    VStack {
                        Image(systemName: icons[index])
                            .font(.system(size: 24))
                            .padding(20)
                            .background {
                                Circle()
                                    .foregroundStyle(
                                        Color(uiColor: .secondarySystemGroupedBackground)
                                    )
                            }
                        Text("Icon \(index + 1)")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 13))
                    }
                    if index != 3 {
                        Spacer()
                    }
                }
            }
            .padding(.vertical, 5)
            VStack(alignment: .leading) {
                AsyncImage(url: .init(string: "https://picsum.photos/600/400")) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color(uiColor: .quaternarySystemFill)
                }
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay {
                    ZStack(alignment: .bottomTrailing) {
                        Color.clear
                        Text("4.5")
                            .font(.system(size: 14))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(6)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("7km")
                        .font(.footnote)
                    Text("Parking")
                        .bold()
                        .font(.title3)
                        .foregroundStyle(.primary)
                }
                .padding(6)
            }
            .foregroundStyle(.secondary)
            .padding(4)
            .background {
                Color(uiColor: .secondarySystemGroupedBackground)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.vertical, 8)
            Text("Lorem ipsum dolor sit amet, consectetur adipiscing elit. In malesuada facilisis ornare. Vestibulum faucibus erat eu quam iaculis facilisis. Sed fringilla tempus bibendum. Sed eu consectetur est. Sed cursus ex at diam ornare, non viverra sapien consectetur.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(7)
            VStack(spacing: 14) {
                ForEach(0..<20, id: \.self) { i in
                    HStack {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Rectangle()
                                    .frame(width: 10, height: 10)
                                    .rotationEffect(.degrees(45))
                                    .frame(width: 14, height: 14)
                                Text("+\(String(format: "%.3f", Double.random(in: 1..<10)))")
                                    .foregroundStyle(Color.init(red: 102.0 / 255, green: 240.0 / 255, blue: 195.0 / 255))
                                    .font(.system(size: 11))
                            }
                            HStack(alignment: .top, spacing: 1) {
                                Text("$")
                                    .font(.system(size: 9))
                                    .offset(y: 2)
                                Text(String(Int.random(in: 100..<10000)))
                                    .font(.system(size: 14))
                                    .bold()
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(width: 60)
                        .padding([.horizontal, .top], 8)
                        .padding(.bottom, 7)
                        .background {
                            Color.blue
                                .opacity(0.9)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Item \(i + 1)")
                                .bold()
                            Text("Subitem \(i + 1)")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 15))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("$\(Int.random(in: 1000..<100000))")
                                .bold()
                            Text("USDT")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 15))
                        }
                    }
                    .frame(height: 58)
                }
            }
            .padding(12)
            .background {
                Color(uiColor: .secondarySystemGroupedBackground)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22))
        }
        .padding(.horizontal)
        .padding(.bottom)
        .ignoresSafeArea()
    }
}

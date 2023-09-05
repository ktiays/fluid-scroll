//
//  Created by ktiays on 2023/9/5.
//  Copyright (c) 2023 ktiays. All rights reserved.
// 

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
    
    var body: some View {
        VStack {
            VStack(spacing: 12) {
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
            .padding()
        }
        .ignoresSafeArea()
    }
}

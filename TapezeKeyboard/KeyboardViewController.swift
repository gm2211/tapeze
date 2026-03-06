import UIKit
import SwiftUI

class KeyboardViewController: UIInputViewController {

    private var keyboardState = KeyboardState()
    private var hostingController: UIHostingController<KeyboardView>?

    override func viewDidLoad() {
        super.viewDidLoad()

        let keyboardView = KeyboardView(
            state: keyboardState,
            onCharacter: { [weak self] char in
                self?.textDocumentProxy.insertText(char)
            },
            onBackspace: { [weak self] in
                self?.textDocumentProxy.deleteBackward()
            },
            onEnter: { [weak self] in
                self?.textDocumentProxy.insertText("\n")
            },
            onNextKeyboard: { [weak self] in
                self?.advanceToNextInputMode()
            }
        )

        let hc = UIHostingController(rootView: keyboardView)
        hc.view.translatesAutoresizingMaskIntoConstraints = false
        hc.view.backgroundColor = .clear

        addChild(hc)
        view.addSubview(hc.view)
        hc.didMove(toParent: self)

        NSLayoutConstraint.activate([
            hc.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hc.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hc.view.topAnchor.constraint(equalTo: view.topAnchor),
            hc.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        hostingController = hc
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        // Update height constraint
        let desiredHeight = keyboardState.keyboardHeight
        if let constraint = view.constraints.first(where: { $0.firstAttribute == .height && $0.firstItem === view }) {
            constraint.constant = desiredHeight
        } else {
            let heightConstraint = view.heightAnchor.constraint(equalToConstant: desiredHeight)
            heightConstraint.priority = .defaultHigh
            heightConstraint.isActive = true
        }
    }

    override func textWillChange(_ textInput: UITextInput?) {
        // Called when the text is about to change
    }

    override func textDidChange(_ textInput: UITextInput?) {
        // Called when the text has changed
    }
}

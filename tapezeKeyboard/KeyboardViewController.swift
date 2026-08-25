import UIKit
import SwiftUI
import Combine

class KeyboardViewController: UIInputViewController {

    private var keyboardState = KeyboardState()
    private var hostingController: UIHostingController<KeyboardView>?
    private var heightConstraint: NSLayoutConstraint?
    private var heightCancellable: AnyCancellable?

    override func viewDidLoad() {
        super.viewDidLoad()
        configureTransparentBackgrounds()

        let heightConstraint = view.heightAnchor.constraint(equalToConstant: keyboardState.keyboardHeight)
        heightConstraint.priority = .defaultHigh
        heightConstraint.isActive = true
        self.heightConstraint = heightConstraint

        let keyboardView = KeyboardView(
            state: keyboardState,
            onCharacter: { [weak self] char in
                self?.textDocumentProxy.insertText(char)
                self?.scheduleInputContextUpdate()
            },
            onBackspace: { [weak self] in
                self?.textDocumentProxy.deleteBackward()
                self?.scheduleInputContextUpdate()
            },
            onDeleteWord: { [weak self] in
                self?.deletePreviousWord()
                self?.scheduleInputContextUpdate()
            },
            onDeleteLine: { [weak self] in
                self?.deleteCurrentLineBeforeCursor()
                self?.scheduleInputContextUpdate()
            },
            onEnter: { [weak self] in
                self?.textDocumentProxy.insertText("\n")
                self?.scheduleInputContextUpdate()
            },
            onMoveCursor: { [weak self] offset in
                self?.textDocumentProxy.adjustTextPosition(byCharacterOffset: offset)
                self?.scheduleInputContextUpdate()
            },
            onNextKeyboard: { [weak self] in
                self?.advanceToNextInputMode()
            }
        )

        let hc = UIHostingController(rootView: keyboardView)
        hc.view.translatesAutoresizingMaskIntoConstraints = false
        hc.view.backgroundColor = .clear
        hc.view.isOpaque = false

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
        bindKeyboardHeight()
        updateInputContext()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureTransparentBackgrounds()
        keyboardState.reloadPersistedAppearanceSettings()
        applyKeyboardHeight(keyboardState.keyboardHeight, animated: false)
        updateInputContext()
    }

    private func configureTransparentBackgrounds() {
        view.backgroundColor = .clear
        view.isOpaque = false
        inputView?.backgroundColor = .clear
        inputView?.isOpaque = false
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        applyKeyboardHeight(keyboardState.keyboardHeight, animated: false)
    }

    private func bindKeyboardHeight() {
        heightCancellable = keyboardState.$keyboardHeight
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] height in
                self?.applyKeyboardHeight(height, animated: true)
            }
    }

    private func applyKeyboardHeight(_ height: CGFloat, animated: Bool) {
        // The constraint constant already matches on a fresh launch because it is
        // created from the persisted height, so it cannot be the only thing we
        // check: preferredContentSize is what actually sizes the input view, and
        // skipping it here left every reopened keyboard at the system height.
        guard heightConstraint?.constant != height || preferredContentSize.height != height else { return }

        heightConstraint?.constant = height
        preferredContentSize = CGSize(width: 0, height: height)

        let updates = {
            self.view.superview?.layoutIfNeeded()
            self.view.layoutIfNeeded()
        }

        if animated {
            UIView.animate(withDuration: 0.18, delay: 0, options: [.beginFromCurrentState, .curveEaseInOut], animations: updates)
        } else {
            updates()
        }
    }

    private func deletePreviousWord() {
        guard let context = textDocumentProxy.documentContextBeforeInput,
              !context.isEmpty else {
            textDocumentProxy.deleteBackward()
            return
        }

        let characters = Array(context)
        var index = characters.count
        var deleteCount = 0

        while index > 0, characters[index - 1].isWhitespace, characters[index - 1] != "\n" {
            index -= 1
            deleteCount += 1
        }

        while index > 0, !characters[index - 1].isWhitespace {
            index -= 1
            deleteCount += 1
        }

        deleteBackward(times: max(deleteCount, 1))
    }

    private func deleteCurrentLineBeforeCursor() {
        guard let context = textDocumentProxy.documentContextBeforeInput,
              !context.isEmpty else {
            textDocumentProxy.deleteBackward()
            return
        }

        var deleteCount = 0
        for character in context.reversed() {
            if character == "\n" { break }
            deleteCount += 1
        }

        deleteBackward(times: max(deleteCount, 1))
    }

    private func deleteBackward(times count: Int) {
        for _ in 0..<count {
            textDocumentProxy.deleteBackward()
        }
    }

    override func textWillChange(_ textInput: UITextInput?) {
        updateInputContext()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        updateInputContext()
    }

    private func updateInputContext() {
        switch textDocumentProxy.keyboardType {
        case .URL, .webSearch:
            keyboardState.isURLField = true
        default:
            keyboardState.isURLField = false
        }

        keyboardState.autocapitalizationMode = Self.autocapitalizationMode(
            for: textDocumentProxy.autocapitalizationType
        )
        keyboardState.updateAutocapitalization(before: textDocumentProxy.documentContextBeforeInput)
    }

    /// Re-reads the document after our own edit. The keyboard clears shift
    /// synchronously once a character is inserted, which would otherwise wipe
    /// the capital `textDidChange` had just raised for the next sentence.
    private func scheduleInputContextUpdate() {
        DispatchQueue.main.async { [weak self] in
            self?.updateInputContext()
        }
    }

    private static func autocapitalizationMode(
        for type: UITextAutocapitalizationType?
    ) -> AutocapitalizationMode {
        // A nil trait means the host never expressed a preference, which for a
        // plain text field behaves as sentence capitalization.
        guard let type else { return .sentences }

        switch type {
        case .none:
            return .none
        case .words:
            return .words
        case .allCharacters:
            return .allCharacters
        case .sentences:
            return .sentences
        @unknown default:
            return .sentences
        }
    }
}
